/// WebSocket Client Service
///
/// Handles WebSocket connection to PC for sending commands
/// and receiving connection status updates.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/command.dart';
import '../../domain/entities/device.dart';

/// Callback for connection state changes
typedef ConnectionStateCallback = void Function(WebSocketConnectionState state);

/// Callback for incoming messages from PC
typedef MessageCallback = void Function(Map<String, dynamic> message);

/// WebSocket connection state
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// WebSocket client for communicating with PC
class WebSocketClient {
  WebSocketChannel? _channel;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  String? _sessionId;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WebSocketConnectionState>.broadcast();
  
  /// Current connection state
  WebSocketConnectionState get state => _state;
  
  /// Session ID from PC (set after connection accepted)
  String? get sessionId => _sessionId;
  
  /// Whether currently connected
  bool get isConnected => _state == WebSocketConnectionState.connected;
  
  /// Stream of incoming messages from PC
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  
  /// Connect to PC via WebSocket
  Future<bool> connect(Device device) async {
    try {
      _updateState(WebSocketConnectionState.connecting);

      final wsUrl = device.websocketUrl;
      print('[WebSocket] Connecting to $wsUrl');

      // Connect to WebSocket
      _channel = await WebSocketChannel.connect(Uri.parse(wsUrl));

      print('[WebSocket] TCP connection established');

      // IMPORTANT: Start listening for messages FIRST before waiting for response
      _listenToMessages();

      // Wait for connection_accepted message with timeout
      print('[WebSocket] Waiting for connection_accepted message...');
      final connected = await _waitForConnectionAccepted();

      if (connected) {
        _updateState(WebSocketConnectionState.connected);
        print('[WebSocket] Connected to PC (session: $_sessionId)');
        return true;
      } else {
        _updateState(WebSocketConnectionState.error);
        print('[WebSocket] Connection failed - no response from PC');
        return false;
      }
    } on TimeoutException catch (e) {
      _updateState(WebSocketConnectionState.error);
      print('[WebSocket] Connection timeout: $e');
      return false;
    } on SocketException catch (e) {
      _updateState(WebSocketConnectionState.error);
      print('[WebSocket] Socket error (check IP/firewall): $e');
      return false;
    } catch (e) {
      _updateState(WebSocketConnectionState.error);
      print('[WebSocket] Connection error: $e');
      return false;
    }
  }
  
  /// Listen for incoming WebSocket messages
  void _listenToMessages() {
    _channel?.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(message);
        } catch (e) {
          print('[WebSocket] Error parsing message: $e');
        }
      },
      onError: (error) {
        print('[WebSocket] Stream error: $error');
        _updateState(WebSocketConnectionState.error);
      },
      onDone: () {
        print('[WebSocket] Connection closed');
        _updateState(WebSocketConnectionState.disconnected);
        _sessionId = null;
      },
    );
  }
  
  /// Handle incoming message from PC
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'connection_accepted':
        _sessionId = message['session_id'] as String?;
        print('[WebSocket] Connection accepted, session: $_sessionId');
        // IMPORTANT: Also forward to message stream so _waitForConnectionAccepted completes
        _messageController.add(message);
        break;

      case 'connection_rejected':
        final reason = message['reason'] as String? ?? 'Unknown reason';
        print('[WebSocket] Connection rejected: $reason');
        _messageController.add(message);
        break;

      case 'heartbeat':
        // Respond to heartbeat
        _sendHeartbeatAck(message['timestamp'] as int?);
        break;

      default:
        // Forward other messages to listeners
        _messageController.add(message);
        break;
    }
  }
  
  /// Wait for connection_accepted message with timeout
  Future<bool> _waitForConnectionAccepted() async {
    final completer = Completer<bool>();
    final timeout = const Duration(seconds: 5);
    
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    
    messages.first.then((message) {
      if (message['type'] == 'connection_accepted' && !completer.isCompleted) {
        completer.complete(true);
      }
    });
    
    return completer.future;
  }
  
  /// Send command to PC
  Future<void> sendCommand(Command command) async {
    if (!isConnected || _channel == null) {
      throw WebSocketException('Not connected');
    }

    try {
      final json = command.toJson();
      // Add timestamp
      json['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      _channel!.sink.add(jsonEncode(json));
      print('[WebSocket] Sent command: ${json['type']}');
    } catch (e) {
      print('[WebSocket] Error sending command: $e');
      rethrow;
    }
  }

  /// Send raw JSON message (for custom messages like screen control)
  Future<void> sendRawMessage(Map<String, dynamic> message) async {
    if (!isConnected || _channel == null) {
      throw WebSocketException('Not connected');
    }

    try {
      message['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      final json = jsonEncode(message);
      print('[WebSocket] Sending raw message: $json');
      _channel!.sink.add(json);
      print('[WebSocket] Sent raw message: ${message['type']}');
    } catch (e) {
      print('[WebSocket] Error sending raw message: $e');
      rethrow;
    }
  }
  
  /// Send heartbeat acknowledgment
  void _sendHeartbeatAck(int? timestamp) {
    if (!isConnected || _channel == null) return;
    
    try {
      final message = {
        'type': 'heartbeat_ack',
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      };
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('[WebSocket] Error sending heartbeat ack: $e');
    }
  }
  
  /// Disconnect from PC
  Future<void> disconnect() async {
    print('[WebSocket] Disconnecting');
    
    try {
      await _channel?.sink.close();
    } catch (e) {
      print('[WebSocket] Error closing connection: $e');
    } finally {
      _channel = null;
      _sessionId = null;
      _updateState(WebSocketConnectionState.disconnected);
    }
  }
  
  /// Update connection state and notify listeners
  void _updateState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }
  
  /// Dispose resources
  void dispose() {
    _messageController.close();
    _stateController.close();
    disconnect();
  }
}

/// WebSocket exception
class WebSocketException implements Exception {
  final String message;
  
  WebSocketException(this.message);
  
  @override
  String toString() => 'WebSocketException: $message';
}
