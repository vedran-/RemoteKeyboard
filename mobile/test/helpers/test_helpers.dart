/// Test Helpers
///
/// Common utilities for integration tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/services.dart';
import 'package:remote_keyboard_mobile/domain/entities/device.dart';

import 'mock_services.dart';

/// Test fixture for integration tests
class IntegrationTestFixture {
  final MockConnectionService connectionService;
  final MockCommandService commandService;
  final MockNotificationService notificationService;

  IntegrationTestFixture()
      : connectionService = MockConnectionService(),
        commandService = MockCommandService(),
        notificationService = MockNotificationService();

  /// Create a test device
  Device createTestDevice({
    String name = 'Test PC',
    String address = '127.0.0.1',
    int port = 8765,
  }) {
    return Device.fromDiscovery(
      name: name,
      address: address,
      port: port,
    );
  }

  /// Verify connection state
  void expectConnected() {
    expect(connectionService.isConnected, isTrue,
        reason: 'Should be connected');
  }

  void expectDisconnected() {
    expect(connectionService.isConnected, isFalse,
        reason: 'Should be disconnected');
  }

  /// Verify notification was shown
  void expectNotificationShown(NotificationType type, {String? message}) {
    expect(
      notificationService.notificationWasShown(type),
      isTrue,
      reason: '$type notification should be shown',
    );

    if (message != null) {
      expect(
        notificationService.lastNotificationMessage(),
        contains(message),
        reason: 'Notification should contain: $message',
      );
    }
  }

  /// Verify command was sent
  void expectCommandSent(String commandType) {
    expect(
      commandService.commandWasSent(commandType),
      isTrue,
      reason: '$commandType command should be sent',
    );
  }

  /// Clean up
  void dispose() {
    connectionService.dispose();
  }
}

/// Common test device
final testDevice = Device.fromDiscovery(
  name: 'Test PC',
  address: '127.0.0.1',
  port: 8765,
);
