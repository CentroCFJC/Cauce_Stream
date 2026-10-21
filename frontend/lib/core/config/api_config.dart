/// Configuracion central del acceso a la API de Cauce.
///
/// El servidor FastAPI vive en la LAN de la Sala Cauce
/// (10.15.0.0/16). Desde un telefono Android `localhost` NO apunta al
/// PC del servidor, por lo que la URL por defecto usa la IP real del
/// nodo central. Puede sobrescribirse en tiempo de compilacion con:
///
///   flutter run --dart-define=CAUCE_API_BASE_URL=http://10.15.1.150:8000/api
library;

import 'dart:core';

class ApiConfig {
  const ApiConfig._();

  /// URL base de la API. Ejemplo: http://10.15.1.150:8000/api
  static const String apiBaseUrl = String.fromEnvironment(
    'CAUCE_API_BASE_URL',
    defaultValue: 'http://10.15.1.150:8000/api',
  );

  /// Prefijo de red de la sala, usado solo con fines informativos en la UI.
  static const String lanSubnet = '10.15.0.0/16';

  static const String loginPath = '/auth/login';
  static const String usersPath = '/users';
  static const String devicesPath = '/devices';
  static const String mediaPath = '/media';
}
