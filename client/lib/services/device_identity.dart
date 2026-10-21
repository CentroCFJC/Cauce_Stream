import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resuelve el device_uid: el nombre del dispositivo tal como lo expone
/// el sistema operativo, SIN normalizar (el servidor lo acepta tal cual,
/// incluidos espacios; máximo 100 caracteres).
class DeviceIdentity {
  DeviceIdentity._();

  static const MethodChannel _channel = MethodChannel('cauce_stream/device');

  /// Límite que exige el backend en `device_uid`.
  static const int maxDeviceUidLength = 100;

  static Future<String> resolve() async {
    final name = await _rawName();
    if (name.length > maxDeviceUidLength) {
      debugPrint(
        '[CAUCE] Nombre de dispositivo demasiado largo (${name.length} > '
        '$maxDeviceUidLength); se trunca: "$name"',
      );
      return name.substring(0, maxDeviceUidLength);
    }
    return name;
  }

  static Future<String> _rawName() async {
    if (Platform.isWindows) {
      final envName = Platform.environment['COMPUTERNAME'];
      final name = (envName != null && envName.trim().isNotEmpty)
          ? envName
          : Platform.localHostname;
      return name.trim();
    }
    if (Platform.isAndroid) {
      try {
        final name = await _channel.invokeMethod<String>('getDeviceName');
        if (name != null && name.trim().isNotEmpty) return name.trim();
      } on PlatformException catch (e) {
        debugPrint('[CAUCE] No se pudo leer el nombre Android: ${e.message}');
      } on MissingPluginException {
        // Canal no disponible (p. ej. en tests): se devuelve vacío y el
        // heartbeat queda deshabilitado desde main.
      }
      return '';
    }
    return Platform.localHostname.trim();
  }
}
