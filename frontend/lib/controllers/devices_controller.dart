/// Controlador del inventario de dispositivos: unica fuente de verdad
/// compartida por Inicio y la pestana Dispositivos.
///
/// Mantiene la ultima lista conocida mientras refresca, para que la UI
/// no parpadee en cada actualizacion. Los conteos por estado alimentan
/// las metricas de la pantalla de Inicio.
///
/// El estado mostrado viene SIEMPRE del servidor: mientras el shell
/// principal esta visible, un sondeo REST periodico (polling) mantiene
/// el inventario al dia sin depender de gestos del usuario.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/network/api_exception.dart';
import '../models/device.dart';
import '../services/device_service.dart';

enum DevicesLoadStatus { idle, loading, ready, error }

class DevicesController extends ChangeNotifier with WidgetsBindingObserver {
  DevicesController({required DeviceService service}) : _service = service {
    WidgetsBinding.instance.addObserver(this);
  }

  final DeviceService _service;

  /// Servicio de dispositivos compartido (registro, autoconfig...).
  DeviceService get service => _service;

  static const Duration staleAfter = Duration(seconds: 15);

  /// Intervalo del sondeo periodico. El cliente late cada 10 s y el
  /// backend marca offline tras 30 s sin heartbeats: sondear cada 10 s
  /// mantiene el chip de estado al dia sin castigar la API.
  static const Duration pollInterval = Duration(seconds: 10);

  List<Device> _devices = const [];
  List<Device> get devices => _devices;

  DevicesLoadStatus _status = DevicesLoadStatus.idle;
  DevicesLoadStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _fetchedAt;

  bool _fetching = false;

  Timer? _pollTimer;
  bool _pollingWanted = false;

  /// Activa el sondeo periodico del inventario. Idempotente; lo llama el
  /// shell principal mientras esta montado, asi Inicio y Dispositivos
  /// comparten un unico ciclo (sin timers por pantalla).
  void startPolling() {
    _pollingWanted = true;
    _startPollTimer();
  }

  /// Detiene el sondeo (al desmontar el shell o al ocultar la app).
  void stopPolling() {
    _pollingWanted = false;
    _stopPollTimer();
  }

  void _startPollTimer() {
    _pollTimer ??= Timer.periodic(pollInterval, (_) => refresh());
  }

  void _stopPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sondear solo con la app visible: en segundo plano no hay UI que
    // actualizar y el ahorro de bateria importa en los moviles de la
    // sala.
    if (state == AppLifecycleState.resumed) {
      if (_pollingWanted) _startPollTimer();
    } else {
      _stopPollTimer();
    }
  }

  @override
  void dispose() {
    stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Carga el inventario si aun no existe o si los datos conocidos ya
  /// caducaron. Las pantallas lo llaman al construirse.
  Future<void> ensureLoaded() async {
    final fetched = _fetchedAt;
    final fresh = fetched != null &&
        DateTime.now().difference(fetched) < staleAfter;
    if (_fetching || (_devices.isNotEmpty && fresh)) return;
    await refresh();
  }

  /// Refresca el inventario contra la API. Nunca lanza: los fallos se
  /// exponen en [errorMessage] conservando la lista anterior. El sondeo
  /// periodico la reutiliza para reintentar silenciosamente cuando el
  /// servidor vuelve a responder.
  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;
    if (_devices.isEmpty) {
      _status = DevicesLoadStatus.loading;
      notifyListeners();
    }
    try {
      _devices = await _service.listDevices();
      _fetchedAt = DateTime.now();
      _errorMessage = null;
      _status = DevicesLoadStatus.ready;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = DevicesLoadStatus.error;
    } finally {
      _fetching = false;
      notifyListeners();
    }
  }

  int get onlineCount => _devices.where((d) => d.isOnline).length;
  int get offlineCount => _devices.where((d) => !d.isOnline).length;
  int get activeCount => _devices.where((d) => d.isActive).length;

  /// Primer dispositivo desconectado, para la alerta de la pantalla de
  /// Inicio.
  Device? get firstOffline {
    for (final d in _devices) {
      if (!d.isOnline) return d;
    }
    return null;
  }
}
