/// RemoteKeyboard Mobile Application
///
/// A two-sided application that allows controlling your PC from a mobile device
/// using a virtual touchpad, keyboard, and media keys.

import 'package:flutter/material.dart';

import 'application/services/services.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final connectionService = ConnectionService();
  final commandService = CommandService(
    connectionService.client,
    connectionService,
  );
  final notificationService = NotificationService();
  
  // Initialize notification settings
  await notificationService.initialize();
  
  final screenStreamService = ScreenStreamService(
    connectionService.client,
    onError: (message, {String? title, bool isError = false}) {
      // Note: Errors are always shown, regardless of notification settings
      // We can't show notifications here without a BuildContext, so these
      // errors will be shown when there's an active context (e.g., from WebSocket)
      debugPrint('[ScreenStream] ${isError ? "ERROR" : "INFO"}: $message');
    },
  );

  runApp(RemoteKeyboardApp(
    connectionService: connectionService,
    commandService: commandService,
    notificationService: notificationService,
    screenStreamService: screenStreamService,
  ));
}

class RemoteKeyboardApp extends StatelessWidget {
  final ConnectionService connectionService;
  final CommandService commandService;
  final NotificationService notificationService;
  final ScreenStreamService screenStreamService;

  const RemoteKeyboardApp({
    super.key,
    required this.connectionService,
    required this.commandService,
    required this.notificationService,
    required this.screenStreamService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemoteKeyboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(
        connectionService: connectionService,
        commandService: commandService,
        notificationService: notificationService,
        screenStreamService: screenStreamService,
      ),
    );
  }
}
