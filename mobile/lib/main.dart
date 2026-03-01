/// RemoteKeyboard Mobile Application
///
/// A two-sided application that allows controlling your PC from a mobile device
/// using a virtual touchpad, keyboard, and media keys.

import 'package:flutter/material.dart';

import 'application/services/services.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const RemoteKeyboardApp());
}

class RemoteKeyboardApp extends StatelessWidget {
  const RemoteKeyboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final connectionService = ConnectionService();
    final commandService = CommandService(
      connectionService.client,
      connectionService,
    );

    return MaterialApp(
      title: 'RemoteKeyboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(
        connectionService: connectionService,
        commandService: commandService,
      ),
    );
  }
}
