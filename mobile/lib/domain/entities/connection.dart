/// Connection Entity
///
/// Represents an active connection to a PC.

import 'device.dart';

class Connection {
  final String id;
  final String sessionId;
  final Device device;
  final DateTime connectedAt;
  final DateTime lastActivity;
  final bool isActive;

  const Connection({
    required this.id,
    required this.sessionId,
    required this.device,
    required this.connectedAt,
    required this.lastActivity,
    this.isActive = true,
  });

  /// Create a new connection
  factory Connection.create(Device device) {
    final now = DateTime.now();
    return Connection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      device: device,
      connectedAt: now,
      lastActivity: now,
      isActive: true,
    );
  }

  /// Update last activity
  Connection copyWithActivity() {
    return Connection(
      id: id,
      sessionId: sessionId,
      device: device,
      connectedAt: connectedAt,
      lastActivity: DateTime.now(),
      isActive: isActive,
    );
  }

  /// Get connection duration in seconds
  int get durationSeconds {
    return DateTime.now().difference(connectedAt).inSeconds;
  }

  /// Get idle time in seconds
  int get idleSeconds {
    return DateTime.now().difference(lastActivity).inSeconds;
  }

  /// Check if connection is stale
  bool isStale(int thresholdSeconds) {
    return idleSeconds > thresholdSeconds;
  }
}
