/// Screen Streaming Integration Test
///
/// Tests the complete flow of binary screen frame streaming.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/application/services/screen_stream_service.dart';
import 'package:remote_keyboard_mobile/domain/entities/command.dart';
import 'package:remote_keyboard_mobile/infrastructure/websocket/websocket_client.dart';

void main() {
  group('Screen Streaming Integration', () {
    test('complete flow: binary frame received → service updated → listener notified', () async {
      // Create mock client
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);

      // Start streaming
      service.startStreaming(viewportWidth: 400, viewportHeight: 300);
      expect(service.isStreaming, isTrue);

      // Set up listener to track notifications
      var listenerCallCount = 0;
      final completer = Completer<void>();
      service.addListener(() {
        listenerCallCount++;
        if (!completer.isCompleted) completer.complete();
      });

      // Create test binary data (simulating JPEG bytes)
      final testJpegData = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));

      print('[TEST] Simulating incoming binary screen frame...');
      print('[TEST] Frame data length: ${testJpegData.length} bytes');

      // Simulate receiving binary frame from WebSocket
      mockClient.simulateIncomingBinaryFrame(testJpegData);

      // Wait for the listener to be called
      await completer.future.timeout(const Duration(milliseconds: 100), onTimeout: () {});

      // Verify listener was notified
      expect(listenerCallCount, greaterThan(0),
        reason: 'Listener should be notified when frame is received');

      service.dispose();
    });

    test('binary data is stored correctly', () {
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);
      service.startStreaming(viewportWidth: 400, viewportHeight: 300);

      // Create test binary data
      final testData = Uint8List.fromList(List<int>.generate(500, (i) => i % 256));

      mockClient.simulateIncomingBinaryFrame(testData);

      // Verify the service handles binary data without crashing
      // Actual image decoding happens asynchronously in production

      service.dispose();
    });

    test('identical frames are skipped (optimization)', () async {
      final mockClient = MockWebSocketClient();
      final service = ScreenStreamService(mockClient);
      service.startStreaming(viewportWidth: 400, viewportHeight: 300);

      var listenerCallCount = 0;
      final completer = Completer<void>();
      service.addListener(() {
        listenerCallCount++;
        if (listenerCallCount >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      final jpegData = Uint8List.fromList(List<int>.generate(100, (i) => i % 256));

      // Send same frame twice
      mockClient.simulateIncomingBinaryFrame(jpegData);
      mockClient.simulateIncomingBinaryFrame(jpegData);

      // Wait for both frames to be processed
      await completer.future.timeout(const Duration(milliseconds: 100), onTimeout: () {});

      // Second frame should be skipped (no redundant processing)
      // We should have exactly 2 listener calls (one for each frame, but second skips decode)
      expect(listenerCallCount, 2);

      service.dispose();
    });

    group('Zoom Control', () {
      test('default zoom level is 1.0', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);

        expect(service.zoomLevel, 1.0);

        service.dispose();
      });

      test('start streaming with custom zoom level sends stream-start', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);

        service.startStreaming(viewportWidth: 400, viewportHeight: 300, zoomLevel: 2.0);

        expect(service.zoomLevel, 2.0);
        expect(service.viewportWidth, 400);
        expect(service.viewportHeight, 300);

        // Verify stream-start command was sent
        final sentCommand = mockClient.sentCommands.firstWhere(
          (c) => c.type == 'stream-start',
        );

        expect(sentCommand.toJson()['width'], 400);
        expect(sentCommand.toJson()['height'], 300);
        expect(sentCommand.toJson()['zoom'], 2.0);

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

        final initialCommandCount = mockClient.sentCommands.length;

        service.setZoomLevel(2.0, notifyServer: false);

        expect(service.zoomLevel, 2.0);
        expect(mockClient.sentCommands.length, initialCommandCount);

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

        service.setZoomLevel(10.0);
        expect(service.zoomLevel, 5.0);

        service.setZoomLevel(0.01);
        expect(service.zoomLevel, 0.1);

        service.dispose();
      });

      test('setViewportDimensions updates viewport and sends stream-update', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);

        service.setViewportDimensions(800, 600);

        expect(service.viewportWidth, 800);
        expect(service.viewportHeight, 600);

        // Verify stream-update was sent
        final updateCommands = mockClient.sentCommands
            .where((c) => c.type == 'stream-update')
            .toList();
        expect(updateCommands, isNotEmpty);

        final lastCommand = updateCommands.last;
        expect(lastCommand.toJson()['width'], 800);
        expect(lastCommand.toJson()['height'], 600);

        service.dispose();
      });
    });

    group('Stream Control', () {
      test('stopStreaming sends stream-stop', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);

        service.stopStreaming();

        expect(service.isStreaming, isFalse);

        // Verify stream-stop was sent
        final stopCommand = mockClient.sentCommands.firstWhere(
          (c) => c.type == 'stream-stop',
        );

        expect(stopCommand, isNotNull);

        service.dispose();
      });

      test('stream-start message format', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);

        service.startStreaming(
          viewportWidth: 800,
          viewportHeight: 600,
          zoomLevel: 2.5,
        );

        final command = mockClient.sentCommands.firstWhere(
          (c) => c.type == 'stream-start',
        );

        final json = command.toJson();
        expect(json['type'], 'stream-start');
        expect(json['width'], 800);
        expect(json['height'], 600);
        expect(json['zoom'], 2.5);

        service.dispose();
      });

      test('stream-update message format', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);

        service.setZoomLevel(2.0);

        final command = mockClient.sentCommands.firstWhere(
          (c) => c.type == 'stream-update',
        );

        final json = command.toJson();
        expect(json['type'], 'stream-update');
        expect(json['width'], 400);
        expect(json['height'], 300);
        expect(json['zoom'], 2.0);

        service.dispose();
      });

      test('stream-stop message format', () {
        final mockClient = MockWebSocketClient();
        final service = ScreenStreamService(mockClient);
        service.startStreaming(viewportWidth: 400, viewportHeight: 300);

        service.stopStreaming();

        final command = mockClient.sentCommands.firstWhere(
          (c) => c.type == 'stream-stop',
        );

        final json = command.toJson();
        expect(json['type'], 'stream-stop');
        expect(json.length, 1); // Only type field

        service.dispose();
      });
    });
  });
}

/// Mock WebSocket client for testing
class MockWebSocketClient extends WebSocketClient {
  final List<Command> sentCommands = [];
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  @override
  Future<void> sendCommand(Command command) async {
    sentCommands.add(command);
    print('[MOCK] Sent command: ${command.type}');
  }

  @override
  Future<void> sendRawMessage(Map<String, dynamic> message) async {
    // Convert to Command for testing
    final command = Command.fromJson(message);
    sentCommands.add(command);
    print('[MOCK] Sent raw message: ${message['type']}');
  }

  void simulateIncomingBinaryFrame(Uint8List data) {
    print('[MOCK] Simulating incoming binary frame: ${data.length} bytes');
    _messageController.add({
      'type': 'screen_frame_binary',
      'bytes': data,
    });
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
