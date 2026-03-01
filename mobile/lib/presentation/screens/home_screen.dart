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

class HomeScreen extends StatefulWidget {
  final ConnectionService connectionService;
  final CommandService commandService;

  const HomeScreen({
    super.key,
    required this.connectionService,
    required this.commandService,
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
      ConnectionScreen(connectionService: widget.connectionService),
      TouchpadScreen(commandService: widget.commandService, connectionService: widget.connectionService),
      KeyboardScreen(commandService: widget.commandService, connectionService: widget.connectionService),
      MediaScreen(commandService: widget.commandService, connectionService: widget.connectionService),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
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
    );
  }
}
