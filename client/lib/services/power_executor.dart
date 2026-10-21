/// Ejecutor de pantalla para los comandos de energía (`power.command`).
///
/// Interfaz inyectable (como `CauceSocketConnector`): el servicio de
/// socket nunca depende de platform channels en pruebas. La
/// implementación de producción (`MethodChannelPowerExecutor`) habla
/// con el lado nativo por el canal `cauce.power/power`.
///
/// Contrato:
/// - `Future<bool>`: true = acción aplicada (idempotente: aplicar "on"
///   con la pantalla ya encendida es éxito, no error); false = la
///   plataforma no permite la acción (p. ej. `enterStandby` en Android:
///   no existe API pública para apagar la pantalla).
/// - Puede lanzar [PowerExecutorException] con un código estable de
///   `PowerErrorCodes` cuando el fallo es distinguible (plataforma sin
///   implementación del canal, error nativo).
library;

import 'package:cauce_stream/models/playback_message.dart';
import 'package:flutter/services.dart';

abstract class PowerExecutor {
  const PowerExecutor();

  /// Entrar en espera (action "off"): apagar la pantalla. El
  /// dispositivo NO se apaga; la app sigue corriendo (heartbeats).
  Future<bool> enterStandby();

  /// Salir de espera (action "on"): encender la pantalla.
  Future<bool> wakeScreen();
}

/// Fallo distinguible del ejecutor con un código estable del contrato
/// (`PowerErrorCodes`); viaja tal cual en `power.error`.
class PowerExecutorException implements Exception {
  const PowerExecutorException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PowerExecutorException($code): $message';
}

/// Implementación de producción: MethodChannel `cauce.power/power`.
///
/// Android: `wakeScreen` enciende la pantalla desde código nativo
/// (wake lock con `ACQUIRE_CAUSES_WAKEUP` + flags de activity);
/// `enterStandby` responde false explícito — Android no ofrece API
/// pública para que una app ponga la pantalla en espera (los caminos
/// reales requieren permisos de firma). Otras plataformas: sin handler
/// nativo → `PowerErrorCodes.platformUnsupported`.
class MethodChannelPowerExecutor implements PowerExecutor {
  const MethodChannelPowerExecutor();

  static const MethodChannel _channel = MethodChannel('cauce.power/power');

  @override
  Future<bool> enterStandby() => _invoke('enterStandby');

  @override
  Future<bool> wakeScreen() => _invoke('wakeScreen');

  Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      throw const PowerExecutorException(
        PowerErrorCodes.platformUnsupported,
        'la plataforma no implementa el canal de energía',
      );
    } on PlatformException catch (e) {
      if (e.code == 'unimplemented' || e.code.isEmpty) {
        throw const PowerExecutorException(
          PowerErrorCodes.platformUnsupported,
          'la plataforma no implementa el canal de energía',
        );
      }
      throw PowerExecutorException(
        e.code.length <= 50 ? e.code : PowerErrorCodes.internalError,
        e.message ?? 'error nativo ejecutando $method',
      );
    }
  }
}
