/// Command Service
///
/// Sends commands to PC via WebSocket.

import '../../domain/entities/command.dart';
import '../../infrastructure/websocket/websocket_client.dart';
import 'connection_service.dart';

/// Service for sending commands to PC
class CommandService {
  final WebSocketClient _client;
  final ConnectionService _connectionService;

  CommandService(this._client, this._connectionService);

  /// Send a command to PC
  Future<bool> sendCommand(Command command) async {
    if (!_connectionService.isConnected) {
      return false;
    }

    try {
      await _client.sendCommand(command);
      return true;
    } catch (e) {
      print('[CommandService] Error sending command: $e');
      return false;
    }
  }

  /// Send mouse move command
  Future<bool> sendMouseMove(int dx, int dy) async {
    return sendCommand(Command.mouseMove(dx, dy));
  }

  /// Send mouse click command
  Future<bool> sendMouseClick(MouseButton button, ButtonState state) async {
    return sendCommand(Command.mouseClick(button, state));
  }

  /// Send mouse scroll command
  Future<bool> sendMouseScroll(int dx, int dy) async {
    return sendCommand(Command.mouseScroll(dx, dy));
  }

  /// Send key press command
  Future<bool> sendKeyPress(String key) async {
    return sendCommand(Command.keyPress(key));
  }

  /// Send text type command
  Future<bool> sendTypeText(String text) async {
    return sendCommand(Command.typeText(text));
  }

  /// Send media key command
  Future<bool> sendMediaKey(MediaAction action) async {
    return sendCommand(Command.mediaKey(action));
  }

  /// Send quick click (press and release)
  Future<bool> sendQuickClick(MouseButton button) async {
    await sendCommand(Command.mouseClick(button, ButtonState.press));
    await Future.delayed(const Duration(milliseconds: 50));
    return sendCommand(Command.mouseClick(button, ButtonState.release));
  }
}
