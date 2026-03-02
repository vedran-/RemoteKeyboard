/// Settings Screen
///
/// Allows users to configure app preferences including notification settings.

import 'package:flutter/material.dart';

import '../../application/services/notification_service.dart';
import '../../infrastructure/config/connection_preferences.dart';

/// Settings screen widget
class SettingsScreen extends StatefulWidget {
  final NotificationService? notificationService;
  
  const SettingsScreen({super.key, this.notificationService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ConnectionPreferences _preferences = ConnectionPreferences();
  
  bool _infoNotificationsEnabled = false;
  bool _successNotificationsEnabled = false;
  bool _commandNotificationsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final infoEnabled = await _preferences.isInfoNotificationsEnabled();
    final successEnabled = await _preferences.isSuccessNotificationsEnabled();
    final commandEnabled = await _preferences.isCommandNotificationsEnabled();
    
    setState(() {
      _infoNotificationsEnabled = infoEnabled;
      _successNotificationsEnabled = successEnabled;
      _commandNotificationsEnabled = commandEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleInfoNotifications(bool value) async {
    await _preferences.setInfoNotificationsEnabled(value);
    setState(() => _infoNotificationsEnabled = value);
    // Reload notification service settings
    await widget.notificationService?.reloadSettings();
  }

  Future<void> _toggleSuccessNotifications(bool value) async {
    await _preferences.setSuccessNotificationsEnabled(value);
    setState(() => _successNotificationsEnabled = value);
    // Reload notification service settings
    await widget.notificationService?.reloadSettings();
  }

  Future<void> _toggleCommandNotifications(bool value) async {
    await _preferences.setCommandNotificationsEnabled(value);
    setState(() => _commandNotificationsEnabled = value);
    // Reload notification service settings
    await widget.notificationService?.reloadSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notifications Section
          _buildSectionHeader('Notifications'),
          const Text(
            'Control which notifications are shown. Error and warning notifications are always shown.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            title: 'Info Notifications',
            subtitle: 'Streaming started/stopped, connection status',
            value: _infoNotificationsEnabled,
            onChanged: _toggleInfoNotifications,
            icon: Icons.info_outline,
            iconColor: Colors.blue,
          ),
          
          _buildSwitchTile(
            title: 'Success Notifications',
            subtitle: 'Connection successful, device added',
            value: _successNotificationsEnabled,
            onChanged: _toggleSuccessNotifications,
            icon: Icons.check_circle,
            iconColor: Colors.green,
          ),
          
          _buildSwitchTile(
            title: 'Command Notifications',
            subtitle: 'Key pressed, mouse click, gesture confirmations',
            value: _commandNotificationsEnabled,
            onChanged: _toggleCommandNotifications,
            icon: Icons.touch_app,
            iconColor: Colors.orange,
          ),
          
          const Divider(height: 32),
          
          // About Section
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.grey),
            title: const Text('Version'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}
