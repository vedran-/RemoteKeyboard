/// Notification Service
///
/// Manages in-app notifications (scaffold messages).
/// Ensures only one notification is shown at a time with proper timing.
/// Respects user preferences for non-error notifications.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../infrastructure/config/connection_preferences.dart';

/// Notification types with different auto-dismiss durations
enum NotificationType {
  /// Info messages (3s, dismissible)
  info,
  
  /// Success messages (2s, dismissible)
  success,
  
  /// Warning messages (4s, dismissible)
  warning,
  
  /// Error messages (5s, dismissible)
  error,
  
  /// Command confirmations (1s, auto-dismiss)
  command,
  
  /// Persistent messages (no auto-dismiss, must be dismissed manually)
  persistent,
}

/// Notification configuration
class NotificationConfig {
  final String message;
  final NotificationType type;
  final Duration? duration;
  final bool dismissible;
  
  const NotificationConfig({
    required this.message,
    this.type = NotificationType.info,
    this.duration,
    this.dismissible = true,
  });
  
  /// Get default duration for notification type
  Duration get effectiveDuration => duration ?? _getDefaultDuration(type);
  
  static Duration _getDefaultDuration(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return const Duration(seconds: 3);
      case NotificationType.success:
        return const Duration(seconds: 2);
      case NotificationType.warning:
        return const Duration(seconds: 4);
      case NotificationType.error:
        return const Duration(seconds: 5);
      case NotificationType.command:
        return const Duration(seconds: 1);
      case NotificationType.persistent:
        return const Duration(seconds: 30); // Long fallback
    }
  }
  
  /// Get background color for notification type
  Color getBackgroundColor(BuildContext context) {
    switch (type) {
      case NotificationType.info:
        return Theme.of(context).colorScheme.primary;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.command:
        return Theme.of(context).colorScheme.secondary;
      case NotificationType.persistent:
        return Theme.of(context).colorScheme.error;
    }
  }
  
  /// Get icon for notification type
  IconData getIcon() {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.command:
        return Icons.touch_app;
      case NotificationType.persistent:
        return Icons.report_problem;
    }
  }
}

/// Service for managing in-app notifications
class NotificationService extends ChangeNotifier {
  NotificationConfig? _currentNotification;
  Timer? _dismissTimer;
  final ConnectionPreferences _preferences = ConnectionPreferences();
  bool _isLoadingSettings = true;
  bool _infoEnabled = false;
  bool _successEnabled = false;
  bool _commandEnabled = false;

  /// Current notification (if any)
  NotificationConfig? get currentNotification => _currentNotification;

  /// Whether a notification is currently showing
  bool get isShowing => _currentNotification != null;

  /// Initialize settings (call this at app startup)
  Future<void> initialize() async {
    _infoEnabled = await _preferences.isInfoNotificationsEnabled();
    _successEnabled = await _preferences.isSuccessNotificationsEnabled();
    _commandEnabled = await _preferences.isCommandNotificationsEnabled();
    _isLoadingSettings = false;
  }

  /// Reload settings (call after user changes settings)
  Future<void> reloadSettings() async {
    _infoEnabled = await _preferences.isInfoNotificationsEnabled();
    _successEnabled = await _preferences.isSuccessNotificationsEnabled();
    _commandEnabled = await _preferences.isCommandNotificationsEnabled();
  }

  /// Show a notification
  ///
  /// Automatically dismisses any previous notification
  /// For non-error notifications, checks user preferences first
  void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    Duration? duration,
  }) {
    // Check if this notification type should be shown based on user preferences
    // Error and persistent notifications are always shown
    // While settings are loading, show notifications
    if (!_isLoadingSettings && !_shouldShowNotification(type)) {
      return; // Skip showing this notification
    }

    // Dismiss any existing notification
    dismiss();

    // Create new notification
    _currentNotification = NotificationConfig(
      message: message,
      type: type,
      duration: duration,
    );

    notifyListeners();

    // Auto-dismiss after duration (unless persistent)
    if (type != NotificationType.persistent) {
      _dismissTimer = Timer(_currentNotification!.effectiveDuration, () {
        dismiss();
      });
    }
  }

  /// Check if notification of given type should be shown based on user preferences
  bool _shouldShowNotification(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return _infoEnabled;
      case NotificationType.success:
        return _successEnabled;
      case NotificationType.command:
        return _commandEnabled;
      case NotificationType.warning:
        // Warnings are always shown (potentially important)
        return true;
      case NotificationType.error:
        // Errors are always shown
        return true;
      case NotificationType.persistent:
        // Persistent notifications are always shown
        return true;
    }
  }
  
  /// Dismiss current notification
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentNotification = null;
    notifyListeners();
  }

  /// Show info notification (respects user preferences)
  void info(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: NotificationType.info, duration: duration);
  }

  /// Show success notification (respects user preferences)
  void success(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: NotificationType.success, duration: duration);
  }

  /// Show warning notification (always shown)
  void warning(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: NotificationType.warning, duration: duration);
  }

  /// Show error notification (always shown)
  void error(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: NotificationType.error, duration: duration);
  }

  /// Show command confirmation (respects user preferences)
  void command(BuildContext context, String message) {
    show(context, message, type: NotificationType.command);
  }

  /// Show persistent notification (always shown)
  void persistent(BuildContext context, String message) {
    show(context, message, type: NotificationType.persistent);
  }
  
  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

/// Widget that displays the current notification as an overlay
class NotificationOverlay extends StatelessWidget {
  final NotificationService service;
  
  const NotificationOverlay({
    super.key,
    required this.service,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final notification = service.currentNotification;
        if (notification == null) {
          return const SizedBox.shrink();
        }
        
        // Don't use Positioned - use Padding instead for compatibility
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: notification.getBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      notification.getIcon(),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (notification.dismissible) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => service.dismiss(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
