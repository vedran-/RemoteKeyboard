/// Screen Stream Service
///
/// Manages screen capture streaming from PC to mobile.
/// Handles receiving screen frames and sending viewport/zoom requests to server.

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
  int _viewportWidth = 400;    // Client's display area width
  int _viewportHeight = 300;   // Client's display area height
  double _zoomLevel = 1.0;     // Current zoom level (0.1 - 5.0)
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

  /// Current viewport width
  int get viewportWidth => _viewportWidth;

  /// Current viewport height
  int get viewportHeight => _viewportHeight;

  /// Current zoom level
  double get zoomLevel => _zoomLevel;

  ScreenStreamService(this._client, {this.onError});

  /// Start screen streaming with viewport dimensions and zoom
  void startStreaming({
    required int viewportWidth,
    required int viewportHeight,
    double zoomLevel = 1.0,
  }) {
    if (_isStreaming) {
      debugPrint('[ScreenStream] Already streaming, ignoring start request');
      onError?.call('Already streaming', title: 'Screen Stream', isError: false);
      return;
    }

    _isStreaming = true;
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
    _zoomLevel = zoomLevel.clamp(0.1, 5.0);

    // Send frame request to PC
    _sendFrameRequest();

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
    debugPrint('[ScreenStream] Streaming started: viewport=${_viewportWidth}x${_viewportHeight}, zoom=${_zoomLevel}x');
    onError?.call('Screen streaming started', title: 'Screen Stream', isError: false);
  }

  /// Stop screen streaming
  void stopStreaming() {
    if (!_isStreaming) return;

    _isStreaming = false;
    _currentFrame = null;

    // Cancel message subscription
    _messageSubscription?.cancel();
    _messageSubscription = null;

    notifyListeners();
    debugPrint('[ScreenStream] Streaming stopped');
  }

  /// Set zoom level (0.1x to 5.0x range)
  /// Higher zoom = server captures more area, scales down (more detail)
  /// Lower zoom = server captures less area, scales up (wider view)
  void setZoomLevel(double zoom, {bool notifyServer = true}) {
    _zoomLevel = zoom.clamp(0.1, 5.0);
    
    // Send updated frame request if streaming and notifyServer is true
    if (_isStreaming && notifyServer) {
      _sendFrameRequest();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Zoom level set to ${_zoomLevel}x');
  }

  /// Reset zoom to 1.0x (100%)
  void resetZoom() {
    setZoomLevel(1.0);
  }

  /// Increase zoom by step (default 0.1x for mouse wheel, 0.25x for pinch)
  void zoomIn({double step = 0.1}) {
    setZoomLevel(_zoomLevel + step);
  }

  /// Decrease zoom by step (default 0.1x for mouse wheel, 0.25x for pinch)
  void zoomOut({double step = 0.1}) {
    setZoomLevel(_zoomLevel - step);
  }

  /// Update viewport dimensions (e.g., when touchpad container size changes)
  void setViewportDimensions(int width, int height) {
    _viewportWidth = width;
    _viewportHeight = height;
    
    // Send updated frame request if streaming
    if (_isStreaming) {
      _sendFrameRequest();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Viewport set to ${_viewportWidth}x${_viewportHeight}');
  }

  /// Send screen frame request to PC
  void _sendFrameRequest() {
    final request = ScreenFrameRequest(
      viewportWidth: _viewportWidth,
      viewportHeight: _viewportHeight,
      zoomLevel: _zoomLevel,
    );

    final message = {
      'type': 'screen_frame_request',
      ...request.toJson(),
    };

    _client.sendRawMessage(message);
    debugPrint('[ScreenStream] Sent frame request: ${_viewportWidth}x${_viewportHeight} @ ${_zoomLevel}x');
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
