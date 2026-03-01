/// Notification Flow Integration Tests
///
/// Tests notification behavior including timing, dismissal, and replacement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/notification_service.dart';

import '../helpers/mock_services.dart';

void main() {
  group('Notification Flow', () {
    late MockNotificationService service;

    setUp(() {
      service = MockNotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test('new notification replaces previous', () {
      // Given: First notification shown
      service.info(_FakeBuildContext(), 'First notification');
      expect(service.notifications, hasLength(1));
      expect(service.notifications.first, 'info:First notification');

      // When: Second notification shown
      service.success(_FakeBuildContext(), 'Second notification');

      // Then: Should have both in history, but only second is "active"
      expect(service.notifications, hasLength(2));
      expect(service.lastNotificationMessage(), 'Second notification');
    });

    test('notifications can be dismissed', () {
      // Given: Notification shown
      service.error(_FakeBuildContext(), 'Error message');
      expect(service.notifications, isNotEmpty);

      // When: Dismissed
      service.dismiss();

      // Then: Notifications cleared
      expect(service.notifications, isEmpty);
    });

    test('different notification types work correctly', () {
      // Test all notification types
      service.info(_FakeBuildContext(), 'Info');
      expect(service.calls.contains('info'), isTrue);

      service.success(_FakeBuildContext(), 'Success');
      expect(service.calls.contains('success'), isTrue);

      service.warning(_FakeBuildContext(), 'Warning');
      expect(service.calls.contains('warning'), isTrue);

      service.error(_FakeBuildContext(), 'Error');
      expect(service.calls.contains('error'), isTrue);

      service.command(_FakeBuildContext(), 'Command');
      expect(service.calls.contains('command'), isTrue);
    });

    test('notification call history is tracked', () {
      // When: Multiple notifications shown
      service.info(_FakeBuildContext(), 'Info 1');
      service.success(_FakeBuildContext(), 'Success 1');
      service.info(_FakeBuildContext(), 'Info 2');

      // Then: Call history should be accurate
      expect(service.calls.contains('info'), isTrue);
      expect(service.calls.contains('success'), isTrue);
      expect(service.calls.contains('error'), isFalse);
    });
  });

  group('Notification Timing', () {
    test('command notifications have shortest duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.command,
      );
      expect(config.effectiveDuration, const Duration(seconds: 1));
    });

    test('success notifications have short duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.success,
      );
      expect(config.effectiveDuration, const Duration(seconds: 2));
    });

    test('info notifications have medium duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.info,
      );
      expect(config.effectiveDuration, const Duration(seconds: 3));
    });

    test('warning notifications have longer duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.warning,
      );
      expect(config.effectiveDuration, const Duration(seconds: 4));
    });

    test('error notifications have longest duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.error,
      );
      expect(config.effectiveDuration, const Duration(seconds: 5));
    });
  });

  group('Notification Content', () {
    test('notification types have appropriate icons', () {
      // Info
      expect(
          const NotificationConfig(message: 'Test', type: NotificationType.info)
              .getIcon(),
          Icons.info_outline);

      // Success
      expect(
          const NotificationConfig(
                  message: 'Test', type: NotificationType.success)
              .getIcon(),
          Icons.check_circle);

      // Warning
      expect(
          const NotificationConfig(
                  message: 'Test', type: NotificationType.warning)
              .getIcon(),
          Icons.warning);

      // Error
      expect(
          const NotificationConfig(message: 'Test', type: NotificationType.error)
              .getIcon(),
          Icons.error_outline);

      // Command
      expect(
          const NotificationConfig(
                  message: 'Test', type: NotificationType.command)
              .getIcon(),
          Icons.touch_app);
    });

    test('notification messages are preserved', () {
      final service = MockNotificationService();

      service.info(_FakeBuildContext(), 'Custom message here');

      expect(service.lastNotificationMessage(), 'Custom message here');

      service.dispose();
    });
  });
}

// Fake BuildContext for testing
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
