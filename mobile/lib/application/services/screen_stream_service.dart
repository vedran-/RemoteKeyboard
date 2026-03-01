/// Screen Stream Service
///
/// Manages screen capture streaming from PC to mobile.
/// Handles receiving screen frames and sending control messages.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/entities/command.dart';
import '../../infrastructure/websocket/websocket_client.dart';

/// Callback for new screen frames
typedef ScreenFrameCallback = void Function(ScreenFrame frame);

/// Service for managing screen streaming from PC
class ScreenStreamService extends ChangeNotifier {
  final WebSocketClient _client;
  
  ScreenFrame? _currentFrame;
  bool _isStreaming = false;
  int _captureWidth = 200;   // Default capture width
  int _captureHeight = 200;  // Default capture height
  int _maxDimension = 400;   // Max dimension for server downscaling
  StreamSubscription? _messageSubscription;

  /// Current screen frame (if any)
  ScreenFrame? get currentFrame => _currentFrame;

  /// Whether streaming is enabled
  bool get isStreaming => _isStreaming;

  /// Current capture width
  int get captureWidth => _captureWidth;

  /// Current capture height
  int get captureHeight => _captureHeight;

  ScreenStreamService(this._client);

  /// Start screen streaming with optional dimensions
  void startStreaming({
    int? captureWidth,
    int? captureHeight,
    int? maxDimension,
  }) {
    if (_isStreaming) return;

    _isStreaming = true;
    _captureWidth = captureWidth ?? 200;
    _captureHeight = captureHeight ?? 200;
    _maxDimension = maxDimension ?? 400;

    // Send control message to PC
    _sendControlMessage();

    // Listen for screen frames
    _messageSubscription = _client.messages.listen((message) {
      // Screen frames are sent directly with type 'screen_frame'
      if (message['type'] == 'screen_frame') {
        _handleScreenFrame(message);
      }
    });

    notifyListeners();
    debugPrint('[ScreenStream] Streaming started at ${_captureWidth}x${_captureHeight}');
  }

  /// Stop screen streaming
  void stopStreaming() {
    if (!_isStreaming) return;

    _isStreaming = false;
    _currentFrame = null;

    // Send control message to stop
    _sendControlMessage();

    // Cancel message subscription
    _messageSubscription?.cancel();
    _messageSubscription = null;

    notifyListeners();
    debugPrint('[ScreenStream] Streaming stopped');
  }

  /// Set capture dimensions (for when touchpad size changes)
  void setCaptureDimensions(int width, int height, {int? maxDimension}) {
    _captureWidth = width.clamp(100, 800);
    _captureHeight = height.clamp(100, 800);
    if (maxDimension != null) {
      _maxDimension = maxDimension.clamp(200, 800);
    }
    
    // Send updated control message if streaming
    if (_isStreaming) {
      _sendControlMessage();
    }
    
    notifyListeners();
    debugPrint('[ScreenStream] Capture dimensions set to ${_captureWidth}x${_captureHeight}');
  }

  /// Send control message to PC
  void _sendControlMessage() {
    final control = ScreenControl(
      enabled: _isStreaming,
      captureWidth: _isStreaming ? _captureWidth : null,
      captureHeight: _isStreaming ? _captureHeight : null,
      maxDimension: _isStreaming ? _maxDimension : null,
    );

    final message = {
      'type': 'custom',
      'payload': control.toJson(),
    };

    _client.sendRawMessage(message);
  }

  /// Handle incoming screen frame
  void _handleScreenFrame(Map<String, dynamic> payload) {
    try {
      _currentFrame = ScreenFrame.fromJson(payload);
      notifyListeners();
      debugPrint(
        '[ScreenStream] Frame received: ${_currentFrame!.captureWidth}x${_currentFrame!.captureHeight}, '
        'cursor: (${_currentFrame!.cursorX}, ${_currentFrame!.cursorY})'
      );
    } catch (e) {
      debugPrint('[ScreenStream] Error parsing screen frame: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
