/// Screen Streaming Integration Test
///
/// Tests the complete flow from WebSocket message to UI update.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/screen_stream_service.dart';
import 'package:remote_keyboard_mobile/domain/entities/command.dart';
import 'package:remote_keyboard_mobile/infrastructure/websocket/websocket_client.dart';

void main() {
  group('Screen Streaming Integration', () {
    test('complete flow: message received → service updated → listener notified', () {
      // Create mock client
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);

      // Start streaming
      service.startStreaming(captureWidth: 400, captureHeight: 300);
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
      // In real app, this happens instantly, but tests need explicit waiting
      // We use a simple delay since the service processes synchronously
      expect(service.currentFrame, isNotNull, 
        reason: 'Frame should be stored after receiving message');
      
      if (service.currentFrame != null) {
        print('[TEST] Frame received successfully!');
        print('[TEST] Cursor: (${service.currentFrame!.cursorX}, ${service.currentFrame!.cursorY})');
        print('[TEST] Size: ${service.currentFrame!.captureWidth}x${service.currentFrame!.captureHeight}');
        print('[TEST] Data length: ${service.currentFrame!.data.length} chars');
      } else {
        print('[TEST] ERROR: Frame is null!');
        print('[TEST] Service isStreaming: ${service.isStreaming}');
        print('[TEST] Mock client messages stream has listeners: ${mockClient.hasListeners}');
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

    test('message routing: screen_frame reaches service listener', () {
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);

      var frameReceived = false;
      var messageTypeReceived = <String>[];

      // Start streaming - this sets up the message listener
      service.startStreaming();

      // Also directly listen to client messages to verify they're being sent
      final clientSub = mockClient.messages.listen((msg) {
        print('[TEST] Client message stream received: ${msg['type']}');
        messageTypeReceived.add(msg['type'] as String);
      });

      // Send different message types
      mockClient.simulateIncomingMessage({'type': 'heartbeat'});
      mockClient.simulateIncomingMessage({'type': 'connection_accepted'});
      mockClient.simulateIncomingMessage({
        'type': 'screen_frame',
        'cursor_x': 0,
        'cursor_y': 0,
        'monitor_id': 0,
        'capture_width': 100,
        'capture_height': 100,
        'data': base64Encode([1, 2, 3]),
      });

      // Small delay to allow async processing
      // In a real widget test we'd use pumpAndSettle, but this is a unit test
      print('[TEST] Message types received: $messageTypeReceived');
      
      // Verify screen_frame was received by service
      expect(service.currentFrame, isNotNull,
        reason: 'Screen frame should be received and parsed');
      
      frameReceived = service.currentFrame != null;
      print('[TEST] Frame received: $frameReceived');

      clientSub.cancel();
      service.dispose();
    });

    test('base64 image data can be decoded', () {
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);
      service.startStreaming();

      // Create a minimal valid JPEG (smallest possible)
      // This is a tiny gray JPEG image
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
