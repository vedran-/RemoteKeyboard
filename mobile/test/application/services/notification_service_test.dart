/// Tests for NotificationService
///
/// Verifies notification configuration and behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/notification_service.dart';

void main() {
  group('NotificationConfig', () {
    test('info notification has 3 second duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.info,
      );
      expect(config.effectiveDuration, const Duration(seconds: 3));
    });

    test('success notification has 2 second duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.success,
      );
      expect(config.effectiveDuration, const Duration(seconds: 2));
    });

    test('warning notification has 4 second duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.warning,
      );
      expect(config.effectiveDuration, const Duration(seconds: 4));
    });

    test('error notification has 5 second duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.error,
      );
      expect(config.effectiveDuration, const Duration(seconds: 5));
    });

    test('command notification has 1 second duration', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.command,
      );
      expect(config.effectiveDuration, const Duration(seconds: 1));
    });

    test('persistent notification has 30 second fallback', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.persistent,
      );
      expect(config.effectiveDuration, const Duration(seconds: 30));
    });

    test('custom duration overrides default', () {
      final config = const NotificationConfig(
        message: 'Test',
        type: NotificationType.info,
        duration: Duration(seconds: 10),
      );
      expect(config.effectiveDuration, const Duration(seconds: 10));
    });

    test('all notification types have icons', () {
      for (final type in NotificationType.values) {
        final config = NotificationConfig(message: 'Test', type: type);
        expect(config.getIcon(), isNotNull, reason: '$type should have an icon');
      }
    });

    test('all notifications are dismissible', () {
      for (final type in NotificationType.values) {
        final config = NotificationConfig(message: 'Test', type: type);
        expect(config.dismissible, isTrue, reason: '$type should be dismissible');
      }
    });

    test('NotificationType enum has all expected values', () {
      expect(NotificationType.values.length, 6);
      expect(NotificationType.values, contains(NotificationType.info));
      expect(NotificationType.values, contains(NotificationType.success));
      expect(NotificationType.values, contains(NotificationType.warning));
      expect(NotificationType.values, contains(NotificationType.error));
      expect(NotificationType.values, contains(NotificationType.command));
      expect(NotificationType.values, contains(NotificationType.persistent));
    });
  });
}
