/// Connection Preferences Service
///
/// Saves and loads connection preferences using SharedPreferences.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/device.dart';

/// Service for managing connection preferences
class ConnectionPreferences {
  static const String _lastDeviceKey = 'last_connected_device';
  static const String _autoReconnectKey = 'auto_reconnect_enabled';
  
  // Notification settings
  static const String _enableInfoNotificationsKey = 'enable_info_notifications';
  static const String _enableSuccessNotificationsKey = 'enable_success_notifications';
  static const String _enableCommandNotificationsKey = 'enable_command_notifications';

  /// Save last connected device
  Future<void> saveLastConnectedDevice(Device device) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = {
      'name': device.name,
      'address': device.address,
      'port': device.port,
      'path': device.path,
      'version': device.version,
    };
    await prefs.setString(_lastDeviceKey, jsonEncode(deviceJson));
  }

  /// Load last connected device
  Future<Device?> getLastConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJsonString = prefs.getString(_lastDeviceKey);

    if (deviceJsonString == null) {
      return null;
    }

    try {
      final deviceJson = jsonDecode(deviceJsonString) as Map<String, dynamic>;
      return Device(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: deviceJson['name'] as String,
        address: deviceJson['address'] as String,
        port: deviceJson['port'] as int,
        path: deviceJson['path'] as String,
        version: deviceJson['version'] as String,
        status: DeviceStatus.available,
        lastSeen: DateTime.now(),
      );
    } catch (e) {
      print('[ConnectionPreferences] Error loading last device: $e');
      return null;
    }
  }

  /// Clear last connected device
  Future<void> clearLastConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastDeviceKey);
  }

  /// Check if auto-reconnect is enabled
  Future<bool> isAutoReconnectEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoReconnectKey) ?? true;
  }

  /// Set auto-reconnect enabled
  Future<void> setAutoReconnectEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReconnectKey, enabled);
  }
  
  // ==================== Notification Settings ====================
  
  /// Check if info notifications are enabled (default: false)
  Future<bool> isInfoNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableInfoNotificationsKey) ?? false;
  }
  
  /// Set info notifications enabled
  Future<void> setInfoNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableInfoNotificationsKey, enabled);
  }
  
  /// Check if success notifications are enabled (default: false)
  Future<bool> isSuccessNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableSuccessNotificationsKey) ?? false;
  }
  
  /// Set success notifications enabled
  Future<void> setSuccessNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableSuccessNotificationsKey, enabled);
  }
  
  /// Check if command notifications are enabled (default: false)
  Future<bool> isCommandNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableCommandNotificationsKey) ?? false;
  }
  
  /// Set command notifications enabled
  Future<void> setCommandNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableCommandNotificationsKey, enabled);
  }
}
