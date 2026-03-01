/// Screen Stream Service Tests
///
/// Tests for screen streaming functionality.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/screen_stream_service.dart';
import 'package:remote_keyboard_mobile/domain/entities/command.dart';

void main() {
  group('ScreenStreamService', () {
    late MockWebSocketClient mockClient;
    late ScreenStreamService service;

    setUp(() {
      mockClient = MockWebSocketClient();
      service = ScreenStreamService(mockClient);
    });

    tearDown(() {
      service.dispose();
    });

    test('startStreaming sends control message', () {
      service.startStreaming(
        captureWidth: 600,
        captureHeight: 400,
        maxDimension: 400,
      );

      expect(service.isStreaming, isTrue);
      expect(service.captureWidth, 600);
      expect(service.captureHeight, 400);

      // Verify control message was sent
      expect(mockClient.sentMessages, isNotEmpty);
      final message = mockClient.sentMessages.last;
      expect(message['type'], 'custom');
      expect(message['payload']['enabled'], isTrue);
      expect(message['payload']['capture_width'], 600);
      expect(message['payload']['capture_height'], 400);
      expect(message['payload']['max_dimension'], 400);
    });

    test('stopStreaming sends control message', () {
      service.startStreaming();
      service.stopStreaming();

      expect(service.isStreaming, isFalse);
      expect(service.currentFrame, isNull);

      // Verify stop message was sent
      final message = mockClient.sentMessages.last;
      expect(message['type'], 'custom');
      expect(message['payload']['enabled'], isFalse);
    });

    test('receives and parses screen frame', () {
      // Start streaming
      service.startStreaming();

      // Create a test screen frame (simulate PC sending)
      final testImageData = createTestImageData();
      final screenFrameData = {
        'type': 'screen_frame',
        'cursor_x': 1920,
        'cursor_y': 1080,
        'monitor_id': 1,
        'capture_width': 400,
        'capture_height': 300,
        'data': base64Encode(testImageData),
      };

      // Simulate receiving frame from WebSocket
      mockClient.simulateIncomingMessage(screenFrameData);

      // Verify frame was received and parsed
      expect(service.currentFrame, isNotNull);
      expect(service.currentFrame!.cursorX, 1920);
      expect(service.currentFrame!.cursorY, 1080);
      expect(service.currentFrame!.captureWidth, 400);
      expect(service.currentFrame!.captureHeight, 300);
      expect(service.currentFrame!.data, isNotEmpty);
    });

    test('handles invalid screen frame gracefully', () {
      service.startStreaming();

      // Send invalid frame (missing required fields)
      final invalidFrame = {
        'type': 'screen_frame',
        // Missing cursor_x, cursor_y, etc.
      };

      // Should not crash
      expect(() => mockClient.simulateIncomingMessage(invalidFrame), returnsNormally);
    });

    test('ignores non-screen-frame messages', () {
      service.startStreaming();

      // Send different message types
      mockClient.simulateIncomingMessage({'type': 'heartbeat'});
      mockClient.simulateIncomingMessage({'type': 'connection_accepted'});

      // Should not affect current frame
      expect(service.currentFrame, isNull);
    });

    test('notifies listeners when frame received', () {
      service.startStreaming();

      var listenerCalled = false;
      service.addListener(() {
        listenerCalled = true;
      });

      // Send screen frame
      final testImageData = createTestImageData();
      mockClient.simulateIncomingMessage({
        'type': 'screen_frame',
        'cursor_x': 0,
        'cursor_y': 0,
        'monitor_id': 0,
        'capture_width': 100,
        'capture_height': 100,
        'data': base64Encode(testImageData),
      });

      expect(listenerCalled, isTrue);
    });

    test('can decode base64 image data', () {
      service.startStreaming();

      // Create a small valid PNG image (1x1 pixel transparent)
      final pngData = base64Encode([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
        0x42, 0x60, 0x82,
      ]);

      mockClient.simulateIncomingMessage({
        'type': 'screen_frame',
        'cursor_x': 0,
        'cursor_y': 0,
        'monitor_id': 0,
        'capture_width': 1,
        'capture_height': 1,
        'data': pngData,
      });

      // Verify we can decode the image data
      expect(service.currentFrame, isNotNull);
      final decoded = base64Decode(service.currentFrame!.data);
      expect(decoded, isNotEmpty);
    });

    test('setCaptureDimensions updates dimensions', () {
      service.startStreaming();
      service.setCaptureDimensions(800, 600);

      expect(service.captureWidth, 800);
      expect(service.captureHeight, 600);

      // Verify control message was sent with new dimensions
      final message = mockClient.sentMessages.last;
      expect(message['payload']['capture_width'], 800);
      expect(message['payload']['capture_height'], 600);
    });

    test('clamps capture dimensions to valid range', () {
      service.startStreaming();
      service.setCaptureDimensions(50, 1000);  // Below min, above max

      expect(service.captureWidth, 100);  // Clamped to min
      expect(service.captureHeight, 800); // Clamped to max
    });
  });
}

/// Creates test image data (simple grayscale gradient)
List<int> createTestImageData() {
  // Create a simple 10x10 grayscale image as JPEG-like data
  // This is not a valid JPEG, but sufficient for testing the parsing logic
  final data = <int>[];
  for (var i = 0; i < 100; i++) {
    data.add(i % 256);
  }
  return data;
}

/// Mock WebSocket client for testing
class MockWebSocketClient extends WebSocketClient {
  final List<Map<String, dynamic>> sentMessages = [];
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  @override
  Future<void> sendRawMessage(Map<String, dynamic> message) async {
    sentMessages.add(message);
  }

  void simulateIncomingMessage(Map<String, dynamic> message) {
    _messageController.add(message);
  }

  @override
  void dispose() {
    _messageController.close();
  }
}
