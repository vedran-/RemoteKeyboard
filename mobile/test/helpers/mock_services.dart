/// Mock Services for Testing
///
/// Provides mock implementations of services for integration tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/services.dart' as app;
import 'package:remote_keyboard_mobile/domain/entities/device.dart';
import 'package:remote_keyboard_mobile/domain/entities/connection.dart' as domain;
import 'package:remote_keyboard_mobile/domain/entities/command.dart';

/// Mock ConnectionService for testing (doesn't extend real class to avoid constructor issues)
class MockConnectionService extends ChangeNotifier {
  app.ConnectionState _testState = const app.ConnectionState.disconnected();
  final List<Device> _testDevices = [];
  final List<String> calls = [];

  app.ConnectionState get state => _testState;
  List<Device> get discoveredDevices => _testDevices;
  bool get isConnected => _testState.isConnected;

  /// Set test state
  void setTestState(app.ConnectionState state) {
    _testState = state;
    notifyListeners();
  }

  /// Simulate connection
  void simulateConnect(Device device) {
    _testState = app.ConnectionState.connected(domain.Connection.create(device));
    calls.add('connect');
    notifyListeners();
  }

  /// Simulate disconnection
  void simulateDisconnect() {
    _testState = const app.ConnectionState.disconnected();
    calls.add('disconnect');
    notifyListeners();
  }

  /// Simulate device discovery
  void simulateDeviceFound(Device device) {
    _testDevices.add(device);
    calls.add('device_found');
    notifyListeners();
  }

  /// Clear call history
  void clearCalls() {
    calls.clear();
  }

  /// Verify a call was made
  bool wasCalled(String methodName) {
    return calls.contains(methodName);
  }
}

/// Mock CommandService for testing (doesn't extend real class to avoid constructor issues)
class MockCommandService {
  final List<String> sentCommands = [];
  final List<String> calls = [];

  Future<bool> sendMouseMove(int dx, int dy) async {
    sentCommands.add('mouse_move:$dx,$dy');
    calls.add('sendMouseMove');
    return true;
  }

  @override
  Future<bool> sendMouseClick(MouseButton button, ButtonState state) async {
    sentCommands.add('mouse_click:$button,$state');
    calls.add('sendMouseClick');
    return true;
  }

  @override
  Future<bool> sendMouseScroll(int dx, int dy) async {
    sentCommands.add('mouse_scroll:$dx,$dy');
    calls.add('sendMouseScroll');
    return true;
  }

  @override
  Future<bool> sendKeyPress(String key) async {
    sentCommands.add('key_press:$key');
    calls.add('sendKeyPress');
    return true;
  }

  @override
  Future<bool> sendTypeText(String text) async {
    sentCommands.add('type_text:$text');
    calls.add('sendTypeText');
    return true;
  }

  @override
  Future<bool> sendMediaKey(MediaAction action) async {
    sentCommands.add('media_key:$action');
    calls.add('sendMediaKey');
    return true;
  }

  @override
  Future<bool> sendQuickClick(MouseButton button) async {
    sentCommands.add('quick_click:$button');
    calls.add('sendQuickClick');
    return true;
  }

  /// Clear command history
  void clearCommands() {
    sentCommands.clear();
    calls.clear();
  }

  /// Verify command was sent
  bool commandWasSent(String commandType) {
    return sentCommands.any((cmd) => cmd.startsWith(commandType));
  }
}

/// Mock NotificationService for testing (doesn't extend real class)
class MockNotificationService {
  final List<String> notifications = [];
  final List<String> calls = [];

  void show(
    BuildContext context,
    String message, {
    app.NotificationType type = app.NotificationType.info,
    Duration? duration,
  }) {
    notifications.add('$type:$message');
    calls.add('show:$type');
    // Don't actually show notification in tests
  }

  @override
  void dismiss() {
    notifications.clear();
    calls.add('dismiss');
  }

  void info(BuildContext context, String message, {Duration? duration}) {
    notifications.add('info:$message');
    calls.add('info');
  }

  void success(BuildContext context, String message, {Duration? duration}) {
    notifications.add('success:$message');
    calls.add('success');
  }

  void warning(BuildContext context, String message, {Duration? duration}) {
    notifications.add('warning:$message');
    calls.add('warning');
  }

  void error(BuildContext context, String message, {Duration? duration}) {
    notifications.add('error:$message');
    calls.add('error');
  }

  void command(BuildContext context, String message) {
    notifications.add('command:$message');
    calls.add('command');
  }

  /// Clear notification history
  void clearNotifications() {
    notifications.clear();
    calls.clear();
  }

  /// Verify notification type was shown
  bool notificationWasShown(app.NotificationType type) {
    return notifications.any((notif) => notif.startsWith('$type:'));
  }

  /// Get last notification message
  String? lastNotificationMessage() {
    if (notifications.isEmpty) return null;
    final parts = notifications.last.split(':');
    return parts.length > 1 ? parts.skip(1).join(':') : null;
  }

  void dispose() {
    notifications.clear();
    calls.clear();
  }
}
