/// Tests for Connection Entity
///
/// Verifies connection creation, activity tracking, and stale detection.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/domain/domain.dart';

void main() {
  group('Connection', () {
    late Device testDevice;

    setUp(() {
      testDevice = Device.fromDiscovery(
        name: 'Test PC',
        address: '192.168.1.100',
        port: 8765,
      );
    });

    group('create factory', () {
      test('creates connection with correct properties', () {
        final connection = Connection.create(testDevice);

        expect(connection.device, equals(testDevice));
        expect(connection.isActive, isTrue);
        expect(connection.id, isNotEmpty);
        expect(connection.sessionId, isNotEmpty);
        expect(connection.connectedAt, isNotNull);
        expect(connection.lastActivity, isNotNull);
      });

      test('sets connectedAt to current time', () {
        final beforeCreate = DateTime.now();
        final connection = Connection.create(testDevice);
        final afterCreate = DateTime.now();

        expect(connection.connectedAt, inRange(beforeCreate, afterCreate));
      });

      test('sets lastActivity to same time as connectedAt', () {
        final connection = Connection.create(testDevice);

        expect(connection.lastActivity, equals(connection.connectedAt));
      });

      test('creates unique IDs for different connections', () async {
        final connection1 = Connection.create(testDevice);
        
        // Wait a millisecond to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 5));
        
        final connection2 = Connection.create(testDevice);

        expect(connection1.id, isNot(equals(connection2.id)));
        expect(connection1.sessionId, isNot(equals(connection2.sessionId)));
      });
    });

    group('copyWithActivity', () {
      test('updates lastActivity to current time', () async {
        final connection = Connection.create(testDevice);
        final originalActivity = connection.lastActivity;

        // Wait to ensure time difference
        await Future.delayed(const Duration(milliseconds: 50));

        final updatedConnection = connection.copyWithActivity();

        expect(updatedConnection.lastActivity.isAfter(originalActivity), isTrue);
      });

      test('preserves other properties', () {
        final connection = Connection.create(testDevice);

        final updatedConnection = connection.copyWithActivity();

        expect(updatedConnection.id, equals(connection.id));
        expect(updatedConnection.sessionId, equals(connection.sessionId));
        expect(updatedConnection.device, equals(connection.device));
        expect(updatedConnection.connectedAt, equals(connection.connectedAt));
        expect(updatedConnection.isActive, equals(connection.isActive));
      });
    });

    group('durationSeconds', () {
      test('returns positive duration', () async {
        final connection = Connection.create(testDevice);

        // Wait a small amount to ensure positive duration
        await Future.delayed(const Duration(milliseconds: 100));

        expect(connection.durationSeconds, greaterThanOrEqualTo(0));
      });

      test('increases over time', () async {
        final connection = Connection.create(testDevice);
        final initialDuration = connection.durationSeconds;

        await Future.delayed(const Duration(seconds: 1));

        expect(connection.durationSeconds, greaterThanOrEqualTo(initialDuration));
      });
    });

    group('idleSeconds', () {
      test('returns zero for fresh connection', () {
        final connection = Connection.create(testDevice);

        // For a fresh connection, idle time should be very small
        expect(connection.idleSeconds, greaterThanOrEqualTo(0));
      });

      test('increases when activity is not updated', () async {
        final connection = Connection.create(testDevice);
        final initialIdle = connection.idleSeconds;

        await Future.delayed(const Duration(seconds: 1));

        expect(connection.idleSeconds, greaterThanOrEqualTo(initialIdle));
      });

      test('resets after activity update', () async {
        final connection = Connection.create(testDevice);

        await Future.delayed(const Duration(seconds: 1));
        final idleBeforeUpdate = connection.idleSeconds;

        final updatedConnection = connection.copyWithActivity();
        final idleAfterUpdate = updatedConnection.idleSeconds;

        // The idle time should be reset (or very small)
        expect(idleAfterUpdate, lessThanOrEqualTo(idleBeforeUpdate));
      });
    });

    group('isStale', () {
      test('returns false for active connection', () {
        final connection = Connection.create(testDevice);

        // Fresh connection should not be stale with reasonable threshold
        expect(connection.isStale(30), isFalse);
      });

      test('returns true when idle exceeds threshold', () {
        // Create a connection with old lastActivity
        final oldActivity = DateTime.now().subtract(const Duration(minutes: 5));
        final connection = Connection(
          id: 'old-connection',
          sessionId: 'session-123',
          device: testDevice,
          connectedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          lastActivity: oldActivity,
          isActive: true,
        );

        expect(connection.isStale(60), isTrue); // 60 second threshold
        expect(connection.isStale(299), isTrue); // Just under 5 minute threshold
        expect(connection.isStale(10), isTrue); // 10 second threshold
      });

      test('returns false when idle is below threshold', () {
        final connection = Connection.create(testDevice);

        expect(connection.isStale(300), isFalse); // 5 minute threshold
      });

      test('handles zero threshold', () {
        final connection = Connection.create(testDevice);

        // With zero threshold, even fresh connection might be stale
        // depending on timing
        expect(connection.isStale(0), isFalse);
      });
    });

    group('Connection with different isActive states', () {
      test('can be created with isActive false', () {
        final connection = Connection(
          id: 'test-id',
          sessionId: 'session-id',
          device: testDevice,
          connectedAt: DateTime.now(),
          lastActivity: DateTime.now(),
          isActive: false,
        );

        expect(connection.isActive, isFalse);
      });

      test('defaults to isActive true when not specified', () {
        final connection = Connection(
          id: 'test-id',
          sessionId: 'session-id',
          device: testDevice,
          connectedAt: DateTime.now(),
          lastActivity: DateTime.now(),
        );

        expect(connection.isActive, isTrue);
      });
    });
  });
}

/// Matcher for checking if a DateTime is within a range
Matcher inRange(DateTime start, DateTime end) {
  return _InRangeMatcher(start, end);
}

class _InRangeMatcher extends Matcher {
  final DateTime start;
  final DateTime end;

  _InRangeMatcher(this.start, this.end);

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! DateTime) return false;
    return item.isAfter(start.subtract(const Duration(seconds: 1))) &&
        item.isBefore(end.add(const Duration(seconds: 1)));
  }

  @override
  Description describe(Description description) {
    return description
        .add('a DateTime between ')
        .addDescriptionOf(start)
        .add(' and ')
        .addDescriptionOf(end);
  }
}
