/// Connection Service
///
/// Manages WebSocket connection to PC and device discovery.
/// Uses ChangeNotifier for reactive UI updates.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/device.dart';
import '../../domain/entities/connection.dart';
import '../../infrastructure/websocket/websocket_client.dart';
import '../../infrastructure/mdns/mdns_discovery.dart';

/// Connection state for UI to observe
class ConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final Connection? connection;

  /// Disconnected state
  const ConnectionState.disconnected({this.error})
      : isConnected = false,
        isConnecting = false,
        connection = null;

  /// Connecting state
  const ConnectionState.connecting()
      : isConnected = false,
        isConnecting = true,
        error = null,
        connection = null;

  /// Connected state
  const ConnectionState.connected(Connection connection)
      : isConnected = true,
        isConnecting = false,
        error = null,
        connection = connection;
}

/// Service for managing PC connection
class ConnectionService extends ChangeNotifier {
  final WebSocketClient _client;
  final MDnsDiscovery _discovery;
  
  ConnectionState _state = const ConnectionState.disconnected();
  final List<Device> _discoveredDevices = [];

  ConnectionService()
      : _client = WebSocketClient(),
        _discovery = MDnsDiscovery();

  /// Get the WebSocket client (for CommandService)
  WebSocketClient get client => _client;

  /// Current connection state
  ConnectionState get state => _state;

  /// List of discovered devices
  List<Device> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Whether currently connected
  bool get isConnected => _state.isConnected;

  /// Start device discovery
  void startDiscovery() {
    _discoveredDevices.clear();
    _discovery.startDiscovery().listen((device) {
      if (!_discoveredDevices.any((d) => d.address == device.address)) {
        _discoveredDevices.add(device);
        notifyListeners();
      }
    });
  }

  /// Stop device discovery
  void stopDiscovery() {
    _discovery.stopDiscovery();
  }

  /// Add device manually
  void addManualDevice(String name, String address, {int port = 8765}) {
    final device = Device.fromDiscovery(
      name: name,
      address: address,
      port: port,
    );
    
    if (!_discoveredDevices.any((d) => d.address == address)) {
      _discoveredDevices.add(device);
      notifyListeners();
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(Device device) async {
    _state = const ConnectionState.connecting();
    notifyListeners();

    try {
      final success = await _client.connect(device);

      if (success) {
        _state = ConnectionState.connected(Connection.create(device));
        notifyListeners();
        return true;
      } else {
        _state = const ConnectionState.disconnected(
          error: 'Connection failed',
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = ConnectionState.disconnected(
        error: 'Connection error: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _client.disconnect();
    _state = const ConnectionState.disconnected();
    notifyListeners();
  }

  /// Clear discovered devices
  void clearDevices() {
    _discoveredDevices.clear();
    notifyListeners();
  }

  /// Dispose resources
  void dispose() {
    _client.dispose();
    _discovery.dispose();
  }
}
