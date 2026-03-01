/// Simple WebSocket Test Client for RemoteKeyboard
/// 
/// This is a minimal test client to verify WebSocket connection to PC server.
/// Run this on Windows to test connection without needing the full Flutter app.

import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  print('🎹 RemoteKeyboard - WebSocket Test Client');
  print('=========================================\n');
  
  // Get PC IP from user
  stdout.write('Enter PC IP address (or press Enter for localhost): ');
  final ipInput = stdin.readLineSync()?.trim() ?? '127.0.0.1';
  final pcIp = ipInput.isEmpty ? '127.0.0.1' : ipInput;
  final port = 8765;
  final wsUrl = 'ws://$pcIp:$port/remote';
  
  print('\n📡 Connecting to $wsUrl...');
  
  try {
    // Connect to WebSocket
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    // Wait for connection
    await channel.ready;
    print('✅ CONNECTED to PC server!\n');
    
    // Listen for messages
    channel.stream.listen(
      (message) {
        print('📩 Received: $message');
      },
      onError: (error) {
        print('❌ Error: $error');
      },
      onDone: () {
        print('🔌 Connection closed');
      },
    );
    
    // Send test commands
    print('📤 Sending test commands...\n');
    
    // Test 1: Mouse move
    final mouseMove = {
      'type': 'mouse',
      'payload': {
        'action': 'move',
        'data': {'dx': 10, 'dy': -5}
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    channel.sink.add(jsonEncode(mouseMove));
    print('Sent mouse move: dx=10, dy=-5');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test 2: Mouse click
    final mouseClick = {
      'type': 'mouse',
      'payload': {
        'action': 'click',
        'data': {'button': 'left', 'state': 'press'}
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    channel.sink.add(jsonEncode(mouseClick));
    print('Sent mouse click: left button press');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test 3: Keyboard
    final keyPress = {
      'type': 'keyboard',
      'payload': {
        'action': 'key_press',
        'data': {'key': 'A'}
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    channel.sink.add(jsonEncode(keyPress));
    print('Sent key press: A');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test 4: Media key
    final mediaKey = {
      'type': 'media',
      'payload': {
        'action': 'play_pause'
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    channel.sink.add(jsonEncode(mediaKey));
    print('Sent media key: play_pause');
    
    print('\n✅ All test commands sent successfully!');
    print('\nPress Enter to exit...');
    stdin.readLineSync();
    
    await channel.sink.close();
    
  } catch (e) {
    print('\n❌ FAILED to connect: $e');
    print('\nTroubleshooting:');
    print('1. Make sure PC server is running');
    print('2. Check firewall settings');
    print('3. Verify IP address is correct');
    print('4. Run: netstat -ano | findstr :8765');
  }
}
