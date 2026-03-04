/// Screen Stream Service
///
/// Manages screen capture streaming from PC to mobile.
/// Handles receiving binary screen frames and sending stream control commands.

import 'dart:async';
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
  int _viewportWidth = 400;
  int _viewportHeight = 300;
  double _zoomLevel = 1.0;
  StreamSubscription? _messageSubscription;

  // Cached decoded image to prevent flickering
  ui.Image? _decodedImage;
  Uint8List? _lastImageData;

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

    // Send stream-start command to PC
    _sendStreamStart();

    // Listen for screen frames
    _messageSubscription = _client.messages.listen((message) {
      debugPrint('[ScreenStream] Received message in listener: ${message['type']}');
      // Binary screen frames are sent with type 'screen_frame_binary'
      if (message['type'] == 'screen_frame_binary') {
        debugPrint('[ScreenStream] Found screen_frame_binary, handling it');
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

    // Send stream-stop command to PC
    _sendStreamStop();

    _isStreaming = false;
    _currentFrame = null;

    // Cancel message subscription
    _messageSubscription?.cancel();
    _messageSubscription = null;

    notifyListeners();
    debugPrint('[ScreenStream] Streaming stopped');
  }

  /// Set zoom level (0.1x to 5.0x range)
  void setZoomLevel(double zoom, {bool notifyServer = true}) {
    _zoomLevel = zoom.clamp(0.1, 5.0);

    // Send updated stream-update if streaming and notifyServer is true
    if (_isStreaming && notifyServer) {
      _sendStreamUpdate();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Zoom level set to ${_zoomLevel}x');
  }

  /// Reset zoom to 1.0x (100%)
  void resetZoom() {
    setZoomLevel(1.0);
  }

  /// Increase zoom by step
  void zoomIn({double step = 0.1}) {
    setZoomLevel(_zoomLevel + step);
  }

  /// Decrease zoom by step
  void zoomOut({double step = 0.1}) {
    setZoomLevel(_zoomLevel - step);
  }

  /// Update viewport dimensions
  void setViewportDimensions(int width, int height) {
    _viewportWidth = width;
    _viewportHeight = height;

    // Send stream-update if streaming
    if (_isStreaming) {
      _sendStreamUpdate();
    }

    notifyListeners();
    debugPrint('[ScreenStream] Viewport set to ${_viewportWidth}x${_viewportHeight}');
  }

  /// Send stream-start command to PC
  void _sendStreamStart() {
    final command = Command.streamStart(
      width: _viewportWidth,
      height: _viewportHeight,
      zoom: _zoomLevel,
    );
    _client.sendCommand(command);
    debugPrint('[ScreenStream] Sent stream-start: ${_viewportWidth}x${_viewportHeight} @ ${_zoomLevel}x');
  }

  /// Send stream-update command to PC
  void _sendStreamUpdate() {
    final command = Command.streamUpdate(
      width: _viewportWidth,
      height: _viewportHeight,
      zoom: _zoomLevel,
    );
    _client.sendCommand(command);
    debugPrint('[ScreenStream] Sent stream-update: ${_viewportWidth}x${_viewportHeight} @ ${_zoomLevel}x');
  }

  /// Send stream-stop command to PC
  void _sendStreamStop() {
    final command = Command.streamStop();
    _client.sendCommand(command);
    debugPrint('[ScreenStream] Sent stream-stop');
  }

  /// Handle incoming binary screen frame
  void _handleScreenFrame(Map<String, dynamic> message) {
    try {
      final bytes = message['bytes'] as Uint8List;
      print('[ScreenStream] Received binary frame: ${bytes.length} bytes');

      // Store frame immediately
      _currentFrame = ScreenFrame.fromBinary(bytes);

      // Check if image data changed (avoid redundant decoding)
      if (_lastImageData != null &&
          bytes.length == _lastImageData!.length &&
          _areBytesEqual(bytes, _lastImageData!)) {
        print('[ScreenStream] Image unchanged, skipping decode');
        notifyListeners();
        return;
      }

      _lastImageData = bytes;

      // Notify listeners immediately (before async decode)
      notifyListeners();

      // Verify data is valid
      if (bytes.isEmpty) {
        debugPrint('[ScreenStream] Warning: Empty image data');
      } else {
        // Decode image asynchronously
        try {
          ui.decodeImageFromList(bytes, (decoded) {
            if (decoded != null) {
              print('[ScreenStream] Image decoded: ${decoded.width}x${decoded.height}');
              _decodedImage = decoded;
              // Update frame with actual dimensions
              _currentFrame = ScreenFrame(
                captureWidth: decoded.width,
                captureHeight: decoded.height,
                jpegData: bytes,
              );
              notifyListeners();
            }
          });
        } catch (e) {
          // For testing, we allow invalid images to pass (they'll just show as blank)
          // In production, you might want to handle this differently
          debugPrint('[ScreenStream] Warning: Could not decode image: $e');
        }
      }

      debugPrint(
        '[ScreenStream] Frame received: ${_currentFrame!.captureWidth}x${_currentFrame!.captureHeight}'
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
    _decodedImage?.dispose();
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
