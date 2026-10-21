/// Resultado de encolar un comando de energia en el canal WebSocket
/// del dispositivo (POST /api/devices/{uid}/power, respuesta 202).
library;

/// Confirmacion del servidor: el comando se envio por el socket.
///
/// Fire-and-forget: `delivered` solo indica que habia canal vivo en
/// ese momento; el efecto real (`device_state`) llega despues por
/// heartbeat y se refleja con el polling del inventario. No se
/// persiste nada de esto en el modelo `Device`.
class PowerCommandResult {
  const PowerCommandResult({
    required this.deviceUid,
    required this.commandId,
    required this.action,
    required this.delivered,
  });

  final String deviceUid;
  final int commandId;

  /// 'on' = salir de espera (pantalla encendida).
  /// 'off' = entrar en espera (pantalla apagada).
  final String action;
  final bool delivered;

  factory PowerCommandResult.fromJson(Map<String, dynamic> json) =>
      PowerCommandResult(
        deviceUid: json['device_uid'] as String,
        commandId: json['command_id'] as int,
        action: json['action'] as String,
        delivered: json['delivered'] as bool,
      );
}
