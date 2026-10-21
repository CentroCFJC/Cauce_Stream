/// Modelos de dominio del frontend.
///
/// `Device` refleja el esquema `DeviceRead` del backend
/// (app/schemas/device.py): inventario registrado mas el estado que
/// el servidor deriva de los heartbeats (conectividad + estado
/// operativo activo/en espera).
library;

import '../widgets/identity_widgets.dart';

class Device {
  const Device({
    required this.id,
    required this.deviceUid,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ipAddress,
    this.port,
    this.deviceState,
    this.currentApplication,
    this.payload,
    this.lastSeen,
    this.wsConnected = false,
  });

  final int id;

  /// Identificador estable del dispositivo (nombre expuesto por el SO).
  /// La IP puede cambiar; nunca se usa como identidad.
  final String deviceUid;
  final String name;
  final String type;
  final String? ipAddress;
  final int? port;

  /// Conectividad derivada del heartbeat: 'online' | 'offline'.
  final String status;

  /// Estado operativo reportado por el cliente: 'active' | 'idle' | null.
  final String? deviceState;

  /// Aplicacion cliente que el dispositivo reporta en ejecucion.
  final String? currentApplication;

  /// Atributos dinamicos especificos del tipo de dispositivo
  /// (bateria, fuente de energia, etc.).
  final Map<String, dynamic>? payload;

  /// Ultimo heartbeat recibido por el servidor.
  final DateTime? lastSeen;

  /// Canal WebSocket de playback activo en el servidor. Independiente
  /// de [isOnline]: un dispositivo vivo puede no tener canal abierto, y
  /// en ese caso la asignacion de contenido le llega en la proxima
  /// reconexion. Default false (backends sin el campo).
  final bool wsConnected;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as int,
        deviceUid: json['device_uid'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        ipAddress: json['ip_address'] as String?,
        port: json['port'] as int?,
        status: json['status'] as String? ?? 'offline',
        deviceState: json['device_state'] as String?,
        currentApplication: json['current_application'] as String?,
        payload: json['payload'] as Map<String, dynamic>?,
        lastSeen: json['last_seen'] == null
            ? null
            : DateTime.parse(json['last_seen'] as String),
        wsConnected: json['ws_connected'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool get isOnline => status == 'online';

  bool get isActive => isOnline && deviceState == 'active';

  /// Estado combinado para los chips de la UI:
  /// - Desconectado: sin heartbeat reciente (el servidor lo marca offline).
  /// - Activo: en linea y en uso (device_state = active).
  /// - En espera: en linea pero en reposo (device_state = idle).
  /// - En linea: conectividad confirmada sin estado operativo reportado.
  CauceStatus get cauceStatus {
    if (!isOnline) return CauceStatus.offline;
    if (deviceState == 'active') return CauceStatus.active;
    return CauceStatus.online;
  }

  String get statusLabel {
    if (!isOnline) return 'Desconectado';
    if (deviceState == 'active') return 'Activo';
    if (deviceState == 'idle') return 'En espera';
    return 'En linea';
  }

  /// Icono de estacion segun el tipo declarado en el inventario.
  StationKind get station {
    final t = type.toLowerCase();
    bool word(String w) =>
        t == w || t.contains(' $w ') || t.startsWith('$w ') || t.endsWith(' $w');
    if (t.contains('vr') || t.contains('realidad virtual')) {
      return StationKind.vr;
    }
    if (word('ar') || t.contains('aumentada')) return StationKind.ar;
    if (t.contains('tactil') || t.contains('tact')) return StationKind.tactil;
    if (t.contains('audio') || t.contains('sonido')) return StationKind.audio;
    if (t.contains('totem')) return StationKind.totem;
    return StationKind.repositorio;
  }

  /// Tiempo transcurrido desde el ultimo heartbeat, en formato corto.
  /// null cuando el dispositivo nunca se ha comunicado.
  String? get relativeLastSeen {
    final seen = lastSeen;
    if (seen == null) return null;
    final elapsed = DateTime.now().difference(seen);
    if (elapsed.isNegative) return 'hace instantes';
    final seconds = elapsed.inSeconds;
    if (seconds < 60) return 'hace $seconds s';
    final minutes = elapsed.inMinutes;
    if (minutes < 60) return 'hace $minutes min';
    final hours = elapsed.inHours;
    if (hours < 24) return 'hace $hours h';
    return 'hace ${elapsed.inDays} d';
  }

  /// Subtitulo de tarjeta: la aplicacion en ejecucion si el cliente la
  /// reporta; si no, el tipo del inventario.
  String get subtitle => currentApplication ?? type;
}

/// Dispositivo detectado por el autodescubrimiento, aun no registrado.
///
/// Solo identidad de red y estado operativo: el autodescubrimiento no
/// expone atributos dinamicos (`payload`) ni otros detalles del
/// cliente.
class PendingDevice {
  const PendingDevice({
    required this.deviceUid,
    this.ipAddress,
    this.deviceState,
  });

  final String deviceUid;
  final String? ipAddress;
  final String? deviceState;

  factory PendingDevice.fromJson(Map<String, dynamic> json) =>
      PendingDevice(
        deviceUid: json['device_uid'] as String,
        ipAddress: json['ip_address'] as String?,
        deviceState: json['device_state'] as String?,
      );

  String get stateLabel {
    switch (deviceState) {
      case 'active':
        return 'Activo';
      case 'idle':
        return 'En espera';
      default:
        return '';
    }
  }
}
