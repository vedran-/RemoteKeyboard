/// Screen Streaming Integration Test
///
/// Tests the complete flow from WebSocket message to UI update.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/screen_stream_service.dart';
import 'package:remote_keyboard_mobile/infrastructure/websocket/websocket_client.dart';

void main() {
  group('Screen Streaming Integration', () {
    test('complete flow: message received → service updated → listener notified', () {
      // Create mock client
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);

      // Start streaming
      service.startStreaming(viewportWidth: 400, viewportHeight: 300);
      expect(service.isStreaming, isTrue);

      // Set up listener to track notifications
      var listenerCallCount = 0;
      service.addListener(() {
        listenerCallCount++;
        print('[TEST] Listener called! Count: $listenerCallCount');
      });

      // Create test screen frame (simulating PC sending)
      final testImageData = createTestImageData();
      final screenFrameMessage = {
        'type': 'screen_frame',
        'cursor_x': 1920,
        'cursor_y': 1080,
        'monitor_id': 1,
        'capture_width': 400,
        'capture_height': 300,
        'data': base64Encode(testImageData),
      };

      print('[TEST] Simulating incoming screen frame...');
      print('[TEST] Frame data length: ${screenFrameMessage['data'].toString().length} chars');

      // Simulate receiving frame from WebSocket
      mockClient.simulateIncomingMessage(screenFrameMessage);

      // Give async operations time to complete
      expect(service.currentFrame, isNotNull,
        reason: 'Frame should be stored after receiving message');

      if (service.currentFrame != null) {
        print('[TEST] Frame received successfully!');
        print('[TEST] Cursor: (${service.currentFrame!.cursorX}, ${service.currentFrame!.cursorY})');
        print('[TEST] Size: ${service.currentFrame!.captureWidth}x${service.currentFrame!.captureHeight}');
        print('[TEST] Data length: ${service.currentFrame!.data.length} chars');
      }

      // Verify frame was parsed correctly
      expect(service.currentFrame!.cursorX, 1920);
      expect(service.currentFrame!.cursorY, 1080);
      expect(service.currentFrame!.captureWidth, 400);
      expect(service.currentFrame!.captureHeight, 300);

      // Verify listener was notified
      expect(listenerCallCount, greaterThan(0),
        reason: 'Listener should be notified when frame is received');

      service.dispose();
    });

    test('base64 image data can be decoded', () {
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);
      service.startStreaming(viewportWidth: 400, viewportHeight: 300);

      // Create a minimal valid JPEG (smallest possible)
      final minimalJpeg = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC9, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xCC, 0x00, 0x06, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00,
        0x3F, 0x00, 0xFB, 0xD5, 0xDB, 0x20, 0xA8, 0xA8, 0xFF, 0xD9,
      ];

      mockClient.simulateIncomingMessage({
        'type': 'screen_frame',
        'cursor_x': 0,
        'cursor_y': 0,
        'monitor_id': 0,
        'capture_width': 1,
        'capture_height': 1,
        'data': base64Encode(minimalJpeg),
      });

      expect(service.currentFrame, isNotNull);

      // Try to decode the image data
      try {
        final decoded = base64Decode(service.currentFrame!.data);
        print('[TEST] Successfully decoded ${decoded.length} bytes of image data');
        expect(decoded, isNotEmpty);
      } catch (e) {
        print('[TEST] Failed to decode image data: $e');
        fail('Image data should be decodable');
      }

      service.dispose();
    });

    group('Zoom Control', () {
      test('default zoom level is 1.0', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        
        expect(service.zoomLevel, 1.0);
        
        service.dispose();
      });

      test('start streaming with custom zoom level', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        
        // Start with viewport 400x300 at 2.0x zoom
        service.startStreaming(viewportWidth: 400, viewportHeight: 300, zoomLevel: 2.0);
        
        expect(service.zoomLevel, 2.0);
        expect(service.viewportWidth, 400);
        expect(service.viewportHeight, 300);
        
        // Verify request was sent to server
        final requestMessage = mockClient.sentMessages.firstWhere(
          (m) => m['type'] == 'screen_frame_request',
        );
        
        expect(requestMessage['viewport_width'], 400);
        expect(requestMessage['viewport_height'], 300);
        expect(requestMessage['zoom_level'], 2.0);
        
        service.dispose();
      });

      test('zoom in increases zoom level', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        service.zoomIn(step: 0.5);
        expect(service.zoomLevel, 1.5);
        
        service.zoomIn(step: 0.5);
        expect(service.zoomLevel, 2.0);
        
        service.dispose();
      });

      test('zoom out decreases zoom level', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        service.zoomOut(step: 0.5);
        expect(service.zoomLevel, 0.5);
        
        service.dispose();
      });

      test('setZoomLevel with notifyServer=false does not send message', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        final initialMessageCount = mockClient.sentMessages.length;
        
        service.setZoomLevel(2.0, notifyServer: false);
        
        expect(service.zoomLevel, 2.0);
        expect(mockClient.sentMessages.length, initialMessageCount);
        
        service.dispose();
      });

      test('resetZoom returns to 1.0', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300, zoomLevel: 2.5);
        
        service.resetZoom();
        
        expect(service.zoomLevel, 1.0);
        
        service.dispose();
      });

      test('zoom level is clamped to valid range (0.1 to 5.0)', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        // Try to zoom in beyond max (5.0x)
        service.setZoomLevel(10.0);
        expect(service.zoomLevel, 5.0);
        
        // Try to zoom out beyond min (0.1x)
        service.setZoomLevel(0.01);
        expect(service.zoomLevel, 0.1);
        
        service.dispose();
      });

      test('zoomIn with custom step increases zoom', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        service.zoomIn(step: 0.1);
        expect(service.zoomLevel, closeTo(1.1, 0.001));
        
        service.zoomIn(step: 0.1);
        expect(service.zoomLevel, closeTo(1.2, 0.001));
        
        service.dispose();
      });

      test('zoomOut with custom step decreases zoom', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        service.zoomOut(step: 0.1);
        expect(service.zoomLevel, closeTo(0.9, 0.001));
        
        service.zoomOut(step: 0.1);
        expect(service.zoomLevel, closeTo(0.8, 0.001));
        
        service.dispose();
      });

      test('screen_frame_request message format', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        
        service.startStreaming(
          viewportWidth: 800,
          viewportHeight: 600,
          zoomLevel: 2.5,
        );
        
        // Find the request message
        final requestMessage = mockClient.sentMessages.firstWhere(
          (m) => m['type'] == 'screen_frame_request',
        );
        
        expect(requestMessage['type'], 'screen_frame_request');
        expect(requestMessage['viewport_width'], 800);
        expect(requestMessage['viewport_height'], 600);
        expect(requestMessage['zoom_level'], 2.5);
        
        service.dispose();
      });

      test('setViewportDimensions updates viewport and sends request', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);
        
        service.setViewportDimensions(800, 600);
        
        expect(service.viewportWidth, 800);
        expect(service.viewportHeight, 600);
        
        // Verify request was sent
        final messages = mockClient.sentMessages
            .where((m) => m['type'] == 'screen_frame_request')
            .toList();
        expect(messages, isNotEmpty);
        
        final lastMessage = messages.last;
        expect(lastMessage['viewport_width'], 800);
        expect(lastMessage['viewport_height'], 600);
        
        service.dispose();
      });
    });
  });
}

/// Creates test image data
List<int> createTestImageData() {
  // Simple test data (not a valid image, but sufficient for testing parsing)
  return List<int>.generate(1000, (i) => i % 256);
}

/// Mock WebSocket client for testing
class MockWebSocketClient extends WebSocketClient {
  final List<Map<String, dynamic>> sentMessages = [];
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  bool get hasListeners => _messageController.hasListener;

  @override
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  @override
  Future<void> sendRawMessage(Map<String, dynamic> message) async {
    sentMessages.add(message);
  }

  void simulateIncomingMessage(Map<String, dynamic> message) {
    print('[MOCK] Sending message: ${message['type']}');
    _messageController.add(message);
  }

  @override
  void dispose() {
    _messageController.close();
  }
}
