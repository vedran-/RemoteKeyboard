/// Tests for Device Entity
///
/// Verifies device creation, JSON serialization, and discovery functionality.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/domain/domain.dart';

void main() {
  group('Device', () {
    group('fromDiscovery factory', () {
      test('creates device with correct properties', () {
        final device = Device.fromDiscovery(
          name: 'Living Room PC',
          address: '192.168.1.100',
          port: 8765,
        );

        expect(device.name, 'Living Room PC');
        expect(device.address, '192.168.1.100');
        expect(device.port, 8765);
        expect(device.path, '/remote');
        expect(device.version, '1.0');
        expect(device.status, DeviceStatus.available);
        expect(device.lastSeen, isNotNull);
        expect(device.id, isNotEmpty);
      });

      test('creates device with custom path and version', () {
        final device = Device.fromDiscovery(
          name: 'Office PC',
          address: '192.168.1.101',
          port: 9000,
          path: '/custom',
          version: '2.0',
        );

        expect(device.path, '/custom');
        expect(device.version, '2.0');
      });
    });

    group('websocketUrl', () {
      test('generates correct WebSocket URL', () {
        final device = Device.fromDiscovery(
          name: 'Test PC',
          address: '192.168.1.50',
          port: 8765,
        );

        expect(device.websocketUrl, 'ws://192.168.1.50:8765/remote');
      });

      test('generates URL with custom path', () {
        final device = Device.fromDiscovery(
          name: 'Test PC',
          address: '10.0.0.5',
          port: 9000,
          path: '/api/remote',
        );

        expect(device.websocketUrl, 'ws://10.0.0.5:9000/api/remote');
      });
    });

    group('status helpers', () {
      test('isAvailable returns true for available status', () {
        final device = Device.fromDiscovery(
          name: 'Test PC',
          address: '192.168.1.1',
          port: 8765,
        );

        expect(device.isAvailable, isTrue);
      });

      test('isAvailable returns false for connected status', () {
        final device = Device(
          id: '1',
          name: 'Test PC',
          address: '192.168.1.1',
          port: 8765,
          path: '/remote',
          version: '1.0',
          status: DeviceStatus.connected,
        );

        expect(device.isAvailable, isFalse);
      });

      test('isConnected returns true for connected status', () {
        final device = Device(
          id: '1',
          name: 'Test PC',
          address: '192.168.1.1',
          port: 8765,
          path: '/remote',
          version: '1.0',
          status: DeviceStatus.connected,
        );

        expect(device.isConnected, isTrue);
      });

      test('isConnected returns false for available status', () {
        final device = Device.fromDiscovery(
          name: 'Test PC',
          address: '192.168.1.1',
          port: 8765,
        );

        expect(device.isConnected, isFalse);
      });
    });

    group('JSON Serialization', () {
      test('serializes to JSON correctly', () {
        final device = Device(
          id: 'device-123',
          name: 'Living Room PC',
          address: '192.168.1.100',
          port: 8765,
          path: '/remote',
          version: '1.0',
          status: DeviceStatus.available,
          lastSeen: DateTime.utc(2026, 2, 28, 10, 30, 0),
        );

        final json = device.toJson();

        expect(json['id'], 'device-123');
        expect(json['name'], 'Living Room PC');
        expect(json['address'], '192.168.1.100');
        expect(json['port'], 8765);
        expect(json['path'], '/remote');
        expect(json['version'], '1.0');
        expect(json['status'], 'available');
        expect(json['lastSeen'], '2026-02-28T10:30:00.000Z');
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': 'device-456',
          'name': 'Office PC',
          'address': '192.168.1.101',
          'port': 8765,
          'path': '/remote',
          'version': '1.0',
          'status': 'connected',
          'lastSeen': '2026-02-28T11:00:00.000Z',
        };

        final device = Device.fromJson(json);

        expect(device.id, 'device-456');
        expect(device.name, 'Office PC');
        expect(device.address, '192.168.1.101');
        expect(device.port, 8765);
        expect(device.path, '/remote');
        expect(device.version, '1.0');
        expect(device.status, DeviceStatus.connected);
        expect(device.lastSeen, isNotNull);
      });

      test('deserializes with null lastSeen', () {
        final json = {
          'id': 'device-789',
          'name': 'Bedroom PC',
          'address': '192.168.1.102',
          'port': 8765,
          'path': '/remote',
          'version': '1.0',
          'status': 'unavailable',
          'lastSeen': null,
        };

        final device = Device.fromJson(json);

        expect(device.lastSeen, isNull);
      });

      test('round-trip serialization preserves data', () {
        final originalDevice = Device(
          id: 'device-roundtrip',
          name: 'Test PC',
          address: '192.168.1.200',
          port: 9999,
          path: '/api/remote',
          version: '2.0',
          status: DeviceStatus.connecting,
          lastSeen: DateTime.utc(2026, 2, 28, 12, 0, 0),
        );

        final json = originalDevice.toJson();
        final deserialized = Device.fromJson(json);

        expect(deserialized.id, originalDevice.id);
        expect(deserialized.name, originalDevice.name);
        expect(deserialized.address, originalDevice.address);
        expect(deserialized.port, originalDevice.port);
        expect(deserialized.path, originalDevice.path);
        expect(deserialized.version, originalDevice.version);
        expect(deserialized.status, originalDevice.status);
        expect(deserialized.lastSeen, originalDevice.lastSeen);
      });
    });

    group('Device Constructor', () {
      test('creates device with all required fields', () {
        final device = Device(
          id: 'test-id',
          name: 'Test Device',
          address: '127.0.0.1',
          port: 8080,
          path: '/',
          version: '1.0.0',
          status: DeviceStatus.available,
        );

        expect(device.id, 'test-id');
        expect(device.name, 'Test Device');
        expect(device.address, '127.0.0.1');
        expect(device.port, 8080);
        expect(device.path, '/');
        expect(device.version, '1.0.0');
        expect(device.status, DeviceStatus.available);
        expect(device.lastSeen, isNull);
      });
    });
  });

  group('DeviceStatus Enum', () {
    test('has correct number of statuses', () {
      expect(DeviceStatus.values.length, 4);
    });

    test('has expected status names', () {
      expect(DeviceStatus.values.map((e) => e.name), contains('available'));
      expect(DeviceStatus.values.map((e) => e.name), contains('connecting'));
      expect(DeviceStatus.values.map((e) => e.name), contains('connected'));
      expect(DeviceStatus.values.map((e) => e.name), contains('unavailable'));
    });
  });
}
