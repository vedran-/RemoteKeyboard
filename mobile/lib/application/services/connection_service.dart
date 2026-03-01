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
import '../../infrastructure/config/connection_preferences.dart';

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
  final ConnectionPreferences _prefs;

  ConnectionState _state = const ConnectionState.disconnected();
  final List<Device> _discoveredDevices = [];
  
  // Auto-reconnect fields
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  Device? _lastConnectedDevice;
  bool _isReconnecting = false;

  ConnectionService()
      : _client = WebSocketClient(),
        _discovery = MDnsDiscovery(),
        _prefs = ConnectionPreferences() {
    // Try to reconnect to last PC on cold start
    _reconnectToLastDevice();
  }

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

  /// Reconnect to last device on cold start
  Future<void> _reconnectToLastDevice() async {
    final lastDevice = await _prefs.getLastConnectedDevice();
    if (lastDevice != null) {
      // Attempt to reconnect to last device
      connectToDevice(lastDevice);
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(Device device) async {
    // Cancel any existing reconnect
    _cancelReconnect();
    
    _state = const ConnectionState.connecting();
    notifyListeners();

    try {
      final success = await _client.connect(device);

      if (success) {
        _state = ConnectionState.connected(Connection.create(device));
        _lastConnectedDevice = device;
        _isReconnecting = false;
        
        // Save to preferences for cold start reconnect
        _prefs.saveLastConnectedDevice(device);
        
        notifyListeners();
        
        // Start monitoring for auto-reconnect
        _startReconnectMonitoring();
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

  /// Start monitoring connection for auto-reconnect
  void _startReconnectMonitoring() {
    // Monitor heartbeat/connection state
    _client.stateStream.listen((wsState) {
      if (wsState == WebSocketConnectionState.error ||
          wsState == WebSocketConnectionState.disconnected) {
        if (!_isReconnecting && _lastConnectedDevice != null) {
          _startAutoReconnect();
        }
      }
    });
  }

  /// Start auto-reconnect with exponential backoff
  void _startAutoReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _state = const ConnectionState.disconnected(
        error: 'Connection lost. Max reconnect attempts reached.',
      );
      _isReconnecting = false;
      _reconnectAttempts = 0;
      notifyListeners();
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    // Calculate delay with exponential backoff
    final delay = Duration(
      milliseconds: (1000 * _reconnectAttempts).clamp(1000, 30000),
    );

    _state = ConnectionState.disconnected(
      error: 'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
    );
    notifyListeners();

    _reconnectTimer = Timer(delay, () {
      if (_lastConnectedDevice != null) {
        connectToDevice(_lastConnectedDevice!);
      }
    });
  }

  /// Cancel auto-reconnect
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isReconnecting = false;
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _cancelReconnect();
    _lastConnectedDevice = null;
    // Clear saved device when user manually disconnects
    _prefs.clearLastConnectedDevice();
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
  @override
  void dispose() {
    _cancelReconnect();
    _client.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
