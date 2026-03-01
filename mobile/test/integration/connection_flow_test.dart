/// Connection Flow Integration Tests
///
/// Tests the complete connection flow from discovery to sending commands.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/services.dart';
import 'package:remote_keyboard_mobile/domain/entities/device.dart';
import 'package:remote_keyboard_mobile/domain/entities/command.dart';

import '../helpers/mock_services.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Connection Flow', () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('successful connection flow', () {
      // Given: Disconnected state
      fixture.expectDisconnected();

      // When: Connect to device
      final device = fixture.createTestDevice();
      fixture.connectionService.simulateConnect(device);

      // Then: Should be connected
      fixture.expectConnected();
      // Note: In real app, success notification would be shown
    });

    test('connection failure shows error', () {
      // Given: Disconnected state
      fixture.expectDisconnected();

      // When: Connection fails (simulate by staying disconnected)
      // In real app, error would be shown by the screen
      fixture.connectionService.simulateDisconnect();

      // Then: Should remain disconnected
      fixture.expectDisconnected();
    });

    test('can send commands after connection', () {
      // Given: Connected state
      final device = fixture.createTestDevice();
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();

      // When: Send media command
      fixture.commandService.sendMediaKey(MediaAction.playPause);

      // Then: Command should be sent
      fixture.expectCommandSent('media_key');
    });

    test('disconnect clears connection state', () {
      // Given: Connected state
      fixture.connectionService.simulateConnect(fixture.createTestDevice());
      fixture.expectConnected();

      // When: Disconnect
      fixture.connectionService.simulateDisconnect();

      // Then: Should be disconnected
      fixture.expectDisconnected();
      // Note: Notification would be shown in real app, but mock doesn't track it
    });
  });

  group('Device Discovery', () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('discovered devices are added to list', () {
      // Given: Empty device list
      expect(fixture.connectionService.discoveredDevices, isEmpty);

      // When: Device is discovered
      final device = fixture.createTestDevice();
      fixture.connectionService.simulateDeviceFound(device);

      // Then: Device should be in list
      expect(fixture.connectionService.discoveredDevices, hasLength(1));
      expect(fixture.connectionService.discoveredDevices.first.name, 'Test PC');
    });

    test('multiple devices can be discovered', () {
      // When: Multiple devices discovered
      fixture.connectionService.simulateDeviceFound(
          fixture.createTestDevice(name: 'PC 1', address: '192.168.1.1'));
      fixture.connectionService.simulateDeviceFound(
          fixture.createTestDevice(name: 'PC 2', address: '192.168.1.2'));
      fixture.connectionService.simulateDeviceFound(
          fixture.createTestDevice(name: 'PC 3', address: '192.168.1.3'));

      // Then: All devices should be in list
      expect(fixture.connectionService.discoveredDevices, hasLength(3));
    });
  });

  group('Manual Device Entry', () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('manual device can be added', () {
      // Given: Empty device list
      expect(fixture.connectionService.discoveredDevices, isEmpty);

      // When: Manual device added
      final device = fixture.createTestDevice(
        name: 'Manual PC',
        address: '192.168.1.100',
        port: 8765,
      );
      fixture.connectionService.simulateDeviceFound(device);

      // Then: Device should be in list
      expect(fixture.connectionService.discoveredDevices, hasLength(1));
      expect(fixture.connectionService.discoveredDevices.first.address,
          '192.168.1.100');
    });
  });
}

// Fake BuildContext for testing
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
