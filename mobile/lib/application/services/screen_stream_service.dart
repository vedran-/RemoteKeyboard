/// Screen Stream Service
///
/// Manages screen capture streaming from PC to mobile.
/// Handles receiving screen frames and sending control messages.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../domain/entities/command.dart';
import '../../infrastructure/websocket/websocket_client.dart';

/// Callback for new screen frames
typedef ScreenFrameCallback = void Function(ScreenFrame frame);

/// Service for managing screen streaming from PC
class ScreenStreamService extends ChangeNotifier {
  final WebSocketClient _client;
  final void Function(String message, {String? title, bool isError})? onError;
  
  ScreenFrame? _currentFrame;
  bool _isStreaming = false;
  int _captureWidth = 200;   // Default capture width
  int _captureHeight = 200;  // Default capture height
  int _maxDimension = 400;   // Max dimension for server downscaling
  StreamSubscription? _messageSubscription;
  
  // Cached decoded image to prevent flickering
  ui.Image? _decodedImage;
  Uint8List? _lastImageData;  // To detect if image data changed

  /// Current screen frame (if any)
  ScreenFrame? get currentFrame => _currentFrame;

  /// Decoded image for display (cached to prevent flickering)
  ui.Image? get decodedImage => _decodedImage;

  /// Whether streaming is enabled
  bool get isStreaming => _isStreaming;

  /// Current capture width
  int get captureWidth => _captureWidth;

  /// Current capture height
  int get captureHeight => _captureHeight;

  ScreenStreamService(this._client, {this.onError});

  /// Start screen streaming with optional dimensions
  void startStreaming({
    int? captureWidth,
    int? captureHeight,
    int? maxDimension,
  }) {
    if (_isStreaming) {
      debugPrint('[ScreenStream] Already streaming, ignoring start request');
      onError?.call('Already streaming', title: 'Screen Stream', isError: false);
      return;
    }

    _isStreaming = true;
    _captureWidth = captureWidth ?? 200;
    _captureHeight = captureHeight ?? 200;
    _maxDimension = maxDimension ?? 400;

    // Send control message to PC
    _sendControlMessage();

    // Listen for screen frames
    _messageSubscription = _client.messages.listen((message) {
      debugPrint('[ScreenStream] Received message in listener: ${message['type']}');
      // Screen frames are sent directly with type 'screen_frame'
      if (message['type'] == 'screen_frame') {
        debugPrint('[ScreenStream] Found screen_frame, handling it');
        _handleScreenFrame(message);
      }
    }, onError: (error) {
      final errorMsg = 'Error receiving screen frames: $error';
      print('[ScreenStream] ERROR: $errorMsg');
      onError?.call(errorMsg, title: 'Screen Stream Error', isError: true);
    });

    notifyListeners();
    debugPrint('[ScreenStream] Streaming started at ${_captureWidth}x${_captureHeight}');
    onError?.call('Screen streaming started', title: 'Screen Stream', isError: false);
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
      print('[ScreenStream] Parsing screen frame...');
      _currentFrame = ScreenFrame.fromJson(payload);
      print('[ScreenStream] Frame parsed successfully: ${_currentFrame!.captureWidth}x${_currentFrame!.captureHeight}');
      
      // Check if image data actually changed (avoid redundant decoding)
      final newImageData = base64Decode(_currentFrame!.data);
      if (_lastImageData != null && 
          newImageData.length == _lastImageData!.length &&
          _areBytesEqual(newImageData, _lastImageData!)) {
        // Image data is the same, skip decoding
        print('[ScreenStream] Image unchanged, skipping decode');
        notifyListeners();
        return;
      }
      
      _lastImageData = newImageData;
      
      // Verify data is valid base64
      try {
        if (newImageData.isEmpty) {
          throw Exception('Image data is empty');
        }
        
        // Decode image asynchronously (doesn't block UI)
        ui.decodeImageFromList(newImageData, (decoded) {
          print('[ScreenStream] Image decoded: ${decoded.width}x${decoded.height}');
          _decodedImage = decoded;
          notifyListeners();
        });
      } catch (e) {
        final errorMsg = 'Invalid image data: $e';
        print('[ScreenStream] ERROR: $errorMsg');
        onError?.call(errorMsg, title: 'Screen Stream Error', isError: true);
        return;
      }
      
      debugPrint(
        '[ScreenStream] Frame received: ${_currentFrame!.captureWidth}x${_currentFrame!.captureHeight}, '
        'cursor: (${_currentFrame!.cursorX}, ${_currentFrame!.cursorY})'
      );
    } catch (e) {
      final errorMsg = 'Failed to parse screen frame: $e';
      print('[ScreenStream] ERROR: $errorMsg');
      onError?.call(errorMsg, title: 'Screen Stream Error', isError: true);
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    stopStreaming();
    _decodedImage?.dispose();  // Clean up decoded image
    super.dispose();
  }
  
  /// Compare two byte arrays for equality
  bool _areBytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
