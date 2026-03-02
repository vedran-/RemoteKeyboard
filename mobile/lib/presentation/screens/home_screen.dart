/// Home Screen - Main navigation
///
/// Provides tabs for:
/// - Touchpad
/// - Keyboard
/// - Media Keys

import 'package:flutter/material.dart';

import '../../application/services/services.dart';
import 'touchpad_screen.dart';
import 'keyboard_screen.dart';
import 'media_screen.dart';
import 'connection_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ConnectionService connectionService;
  final CommandService commandService;
  final NotificationService notificationService;
  final ScreenStreamService screenStreamService;

  const HomeScreen({
    super.key,
    required this.connectionService,
    required this.commandService,
    required this.notificationService,
    required this.screenStreamService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ConnectionScreen(
        connectionService: widget.connectionService,
        notificationService: widget.notificationService,
      ),
      TouchpadScreen(
        commandService: widget.commandService,
        connectionService: widget.connectionService,
        notificationService: widget.notificationService,
        screenStreamService: widget.screenStreamService,
      ),
      KeyboardScreen(
        commandService: widget.commandService,
        connectionService: widget.connectionService,
        notificationService: widget.notificationService,
      ),
      MediaScreen(
        commandService: widget.commandService,
        connectionService: widget.connectionService,
        notificationService: widget.notificationService,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_selectedIndex],
          NotificationOverlay(service: widget.notificationService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi),
            label: 'Connect',
          ),
          NavigationDestination(
            icon: Icon(Icons.touch_app),
            label: 'Touchpad',
          ),
          NavigationDestination(
            icon: Icon(Icons.keyboard),
            label: 'Keyboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Media',
          ),
        ],
      ),
      appBar: _selectedIndex == 0 ? null : AppBar(
        title: _selectedIndex == 1 ? const Text('Touchpad') :
               _selectedIndex == 2 ? const Text('Keyboard') :
               const Text('Media'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    notificationService: widget.notificationService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
