import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controllers/devices_controller.dart';
import 'controllers/media_library_controller.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/cauce_theme.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/media_service.dart';
import 'services/thumbnail_service.dart';
import 'services/user_service.dart';
import 'session/session_controller.dart';
import 'session/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient(baseUrl: ApiConfig.apiBaseUrl);
  final session = SessionController(
    storage: TokenStorage(),
    authService: AuthService(client: apiClient),
    userService: UserService(client: apiClient),
    apiClient: apiClient,
  );
  final devices = DevicesController(
    service: DeviceService(client: apiClient),
  );
  final mediaService = MediaService(client: apiClient);
  final mediaLibrary = MediaLibraryController(
    service: mediaService,
    thumbnails: ThumbnailService(service: mediaService),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: devices),
        ChangeNotifierProvider.value(value: mediaLibrary),
      ],
      child: const CauceApp(),
    ),
  );
}

/// Aplicacion CauceStream.
class CauceApp extends StatelessWidget {
  const CauceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CauceStream',
      debugShowCheckedModeBanner: false,
      theme: CauceTheme.light,
      home: const SessionGate(),
    );
  }
}
