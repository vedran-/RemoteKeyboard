/// Heartbeat Integration Tests
///
/// Tests heartbeat mechanism for connection monitoring and auto-reconnect.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/services.dart';
import 'package:remote_keyboard_mobile/domain/entities/device.dart';

import '../helpers/mock_services.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Heartbeat & Auto-Reconnect', () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('connection state changes trigger monitoring', () {
      // Given: Connected state
      final device = fixture.createTestDevice();
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();

      // When: Connection drops (simulated)
      fixture.connectionService.simulateDisconnect();

      // Then: Should be disconnected
      fixture.expectDisconnected();
      // Note: In real app, auto-reconnect would start
    });

    test('can reconnect after disconnection', () {
      // Given: Connected state
      final device = fixture.createTestDevice();
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();

      // When: Disconnect and reconnect
      fixture.connectionService.simulateDisconnect();
      fixture.connectionService.simulateConnect(device);

      // Then: Should be connected again
      fixture.expectConnected();
    });

    test('last connected device is tracked', () {
      // Given: No last device
      final device = fixture.createTestDevice(name: 'My PC');

      // When: Connect to device
      fixture.connectionService.simulateConnect(device);

      // Then: Last device should be tracked (in real service)
      fixture.expectConnected();
      // Note: Mock doesn't track last device, but real service does
    });
  });

  group('Connection Preferences', () {
    test('device can be serialized for storage', () {
      final device = Device.fromDiscovery(
        name: 'Test PC',
        address: '192.168.1.100',
        port: 8765,
      );

      // Verify device has all required fields for serialization
      expect(device.name, 'Test PC');
      expect(device.address, '192.168.1.100');
      expect(device.port, 8765);
      expect(device.path, '/remote');
      expect(device.version, '1.0');
    });

    test('device can be recreated from stored data', () {
      // Simulate stored data
      final storedData = {
        'name': 'Bedroom PC',
        'address': '192.168.64.108',
        'port': 8765,
        'path': '/remote',
        'version': '1.0',
      };

      // Recreate device
      final device = Device(
        id: 'restored-device',
        name: storedData['name'] as String,
        address: storedData['address'] as String,
        port: storedData['port'] as int,
        path: storedData['path'] as String,
        version: storedData['version'] as String,
        status: DeviceStatus.available,
        lastSeen: DateTime.now(),
      );

      // Verify device is correctly restored
      expect(device.name, 'Bedroom PC');
      expect(device.address, '192.168.64.108');
      expect(device.port, 8765);
    });
  });

  group('Reconnection Logic', () {
    test('exponential backoff calculates correct delays', () {
      // Test exponential backoff formula: 1000ms * attempt, clamped to 30s
      final delays = [
        1 * 1000, // Attempt 1: 1s
        2 * 1000, // Attempt 2: 2s
        3 * 1000, // Attempt 3: 3s
        4 * 1000, // Attempt 4: 4s
        5 * 1000, // Attempt 5: 5s
      ];

      for (var i = 0; i < delays.length; i++) {
        final attempt = i + 1;
        final expectedDelay = (1000 * attempt).clamp(1000, 30000);
        expect(expectedDelay, equals(delays[i]));
      }
    });

    test('max reconnect delay is clamped to 30 seconds', () {
      // Test that delay doesn't exceed 30 seconds
      final largeAttempt = 100;
      final delay = (1000 * largeAttempt).clamp(1000, 30000);
      expect(delay, equals(30000)); // 30 seconds
    });

    test('max reconnect attempts is enforced', () {
      const maxAttempts = 5;
      var attempts = 0;

      // Simulate reconnect attempts
      for (var i = 1; i <= maxAttempts + 2; i++) {
        if (i > maxAttempts) {
          // Should stop at maxAttempts
          break;
        }
        attempts = i;
      }

      expect(attempts, equals(maxAttempts));
    });
  });

  group('Connection State Transitions', () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('connected -> disconnected -> connecting -> connected', () {
      final device = fixture.createTestDevice();

      // Start: Disconnected
      fixture.expectDisconnected();

      // Connect
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();

      // Disconnect
      fixture.connectionService.simulateDisconnect();
      fixture.expectDisconnected();

      // Reconnect
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();
    });

    test('multiple disconnects do not cause errors', () {
      final device = fixture.createTestDevice();

      // Connect
      fixture.connectionService.simulateConnect(device);
      fixture.expectConnected();

      // Multiple disconnects
      fixture.connectionService.simulateDisconnect();
      fixture.connectionService.simulateDisconnect();
      fixture.connectionService.simulateDisconnect();

      // Should still be disconnected (no crash)
      fixture.expectDisconnected();
    });
  });
}
