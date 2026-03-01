/// Device Entity
/// 
/// Represents a PC device that can be connected to.

import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable()
class Device {
  final String id;
  final String name;
  final String address;
  final int port;
  final String path;
  final String version;
  final DeviceStatus status;
  final DateTime? lastSeen;
  
  const Device({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.path,
    required this.version,
    required this.status,
    this.lastSeen,
  });
  
  /// Create from mDNS discovery
  factory Device.fromDiscovery({
    required String name,
    required String address,
    required int port,
    String path = '/remote',
    String version = '1.0',
  }) {
    return Device(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: address,
      port: port,
      path: path,
      version: version,
      status: DeviceStatus.available,
      lastSeen: DateTime.now(),
    );
  }
  
  /// Get WebSocket URL
  String get websocketUrl => 'ws://$address:$port$path';
  
  /// Check if device is available
  bool get isAvailable => status == DeviceStatus.available;
  
  /// Check if device is connected
  bool get isConnected => status == DeviceStatus.connected;
  
  factory Device.fromJson(Map<String, dynamic> json) =>
      _$DeviceFromJson(json);
  
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

/// Device status enumeration
enum DeviceStatus {
  available,
  connecting,
  connected,
  unavailable,
}
