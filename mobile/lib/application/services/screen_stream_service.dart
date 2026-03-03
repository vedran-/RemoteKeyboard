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
  int _baseCaptureWidth = 400;   // Base capture width (at 1.0x zoom)
  int _baseCaptureHeight = 300;  // Base capture height (at 1.0x zoom)
  int _maxDimension = 400;       // Max dimension for server downscaling
  double _zoomLevel = 1.0;       // Current zoom level (1.0 = 100%)
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

  /// Current zoom level
  double get zoomLevel => _zoomLevel;

  /// Get current capture width based on zoom level
  /// Higher zoom = smaller capture area (zoomed in)
  /// Lower zoom = larger capture area (zoomed out)
  int get captureWidth => (_baseCaptureWidth / _zoomLevel).round().clamp(100, 1920);

  /// Get current capture height based on zoom level
  int get captureHeight => (_baseCaptureHeight / _zoomLevel).round().clamp(100, 1080);

  ScreenStreamService(this._client, {this.onError});

  /// Start screen streaming with optional dimensions and zoom
  /// 
  /// [captureWidth] and [captureHeight] are the base dimensions at 1.0x zoom.
  /// Actual capture size will be scaled by zoom level.
  void startStreaming({
    int? captureWidth,
    int? captureHeight,
    int? maxDimension,
    double? zoomLevel,
  }) {
    if (_isStreaming) {
      debugPrint('[ScreenStream] Already streaming, ignoring start request');
      onError?.call('Already streaming', title: 'Screen Stream', isError: false);
      return;
    }

    _isStreaming = true;
    _baseCaptureWidth = captureWidth ?? 400;
    _baseCaptureHeight = captureHeight ?? 300;
    _maxDimension = maxDimension ?? 400;
    _zoomLevel = zoomLevel ?? 1.0;

    // Send control message to PC with calculated dimensions
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
    debugPrint('[ScreenStream] Streaming started at ${captureWidth}x${captureHeight} (zoom: ${_zoomLevel}x, actual: ${this.captureWidth}x${this.captureHeight})');
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

  /// Set base capture dimensions (at 1.0x zoom)
  /// Actual capture size will be scaled by current zoom level
  void setCaptureDimensions(int width, int height, {int? maxDimension}) {
    _baseCaptureWidth = width.clamp(100, 1920);
    _baseCaptureHeight = height.clamp(100, 1080);
    if (maxDimension != null) {
      _maxDimension = maxDimension.clamp(200, 800);
    }

    // Send updated control message if streaming
    if (_isStreaming) {
      _sendControlMessage();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Base dimensions set to ${_baseCaptureWidth}x${_baseCaptureHeight} (actual: ${captureWidth}x${captureHeight} at ${_zoomLevel}x zoom)');
  }

  /// Set zoom level (0.5x to 3.0x range)
  /// Higher zoom = smaller capture area (zoomed in)
  /// Lower zoom = larger capture area (zoomed out)
  void setZoomLevel(double zoom, {bool notifyServer = true}) {
    _zoomLevel = zoom.clamp(0.5, 3.0);
    
    // Send updated control message if streaming and notifyServer is true
    if (_isStreaming && notifyServer) {
      _sendControlMessage();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Zoom level set to ${_zoomLevel}x (capture: ${captureWidth}x${captureHeight})');
  }

  /// Reset zoom to 1.0x (100%)
  void resetZoom() {
    setZoomLevel(1.0);
  }

  /// Increase zoom by step (default 0.25x)
  void zoomIn({double step = 0.25}) {
    setZoomLevel(_zoomLevel + step);
  }

  /// Decrease zoom by step (default 0.25x)
  void zoomOut({double step = 0.25}) {
    setZoomLevel(_zoomLevel - step);
  }

  /// Send control message to PC
  void _sendControlMessage() {
    final control = ScreenControl(
      enabled: _isStreaming,
      captureWidth: _isStreaming ? captureWidth : null,  // Use calculated dimension
      captureHeight: _isStreaming ? captureHeight : null,  // Use calculated dimension
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
