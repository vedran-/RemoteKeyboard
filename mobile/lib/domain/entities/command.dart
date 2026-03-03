/// Command Entity
/// 
/// Commands represent input actions to be sent to the PC.
/// They are the primary domain entity transferred from mobile to PC.

import 'package:json_annotation/json_annotation.dart';

part 'command.g.dart';

/// Core Command entity - represents an input action
@JsonSerializable()
class Command {
  final CommandType type;
  final dynamic payload;
  
  const Command({
    required this.type,
    required this.payload,
  });
  
  /// Create a mouse move command
  factory Command.mouseMove(int dx, int dy) {
    return Command(
      type: CommandType.mouse,
      payload: MouseMovePayload(dx: dx, dy: dy),
    );
  }
  
  /// Create a mouse click command
  factory Command.mouseClick(MouseButton button, ButtonState state) {
    return Command(
      type: CommandType.mouse,
      payload: MouseClickPayload(button: button, state: state),
    );
  }
  
  /// Create a mouse scroll command
  factory Command.mouseScroll(int dx, int dy) {
    return Command(
      type: CommandType.mouse,
      payload: MouseScrollPayload(dx: dx, dy: dy),
    );
  }
  
  /// Create a key press command
  factory Command.keyPress(String key) {
    return Command(
      type: CommandType.keyboard,
      payload: KeyPressPayload(key: key),
    );
  }
  
  /// Create a text typing command
  factory Command.typeText(String text) {
    return Command(
      type: CommandType.keyboard,
      payload: TypeTextPayload(text: text),
    );
  }
  
  /// Create a media key command
  factory Command.mediaKey(MediaAction action) {
    // Map Dart enum names to server's expected snake_case format
    final actionMap = {
      MediaAction.playPause: 'play_pause',
      MediaAction.nextTrack: 'next',
      MediaAction.prevTrack: 'prev',
      MediaAction.volumeUp: 'vol_up',
      MediaAction.volumeDown: 'vol_down',
      MediaAction.mute: 'mute',
    };
    
    return Command(
      type: CommandType.media,
      payload: actionMap[action]!,
    );
  }
  
  /// Convert to JSON for WebSocket transmission
  Map<String, dynamic> toJson() {
    // Serialize payload based on its type
    // Server expects: {"action": "...", "data": {...}} for mouse/keyboard
    final serializedPayload = switch (payload) {
      MouseMovePayload p => {
        'action': 'move',
        'data': p.toJson(),
      },
      MouseClickPayload p => {
        'action': 'click',
        'data': p.toJson(),
      },
      MouseScrollPayload p => {
        'action': 'scroll',
        'data': p.toJson(),
      },
      KeyPressPayload p => {
        'action': 'key_press',
        'data': p.toJson(),
      },
      TypeTextPayload p => {
        'action': 'type_text',
        'data': p.toJson(),
      },
      String s => s,  // Media commands are strings
      _ => payload,
    };

    return {
      'type': type.name,
      'payload': serializedPayload,
    };
  }
  
  /// Create from JSON
  factory Command.fromJson(Map<String, dynamic> json) {
    final type = CommandType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => CommandType.mouse,
    );
    
    return Command(
      type: type,
      payload: json['payload'],
    );
  }
}

/// Command type enumeration
enum CommandType {
  mouse,
  keyboard,
  media,
  custom,
}

/// Screen frame for streaming from PC
class ScreenFrame {
  final int cursorX;
  final int cursorY;
  final int monitorId;
  final int captureWidth;
  final int captureHeight;
  final String data;  // Base64 encoded JPEG

  ScreenFrame({
    required this.cursorX,
    required this.cursorY,
    required this.monitorId,
    required this.captureWidth,
    required this.captureHeight,
    required this.data,
  });

  /// Parse from JSON message
  factory ScreenFrame.fromJson(Map<String, dynamic> json) {
    return ScreenFrame(
      cursorX: json['cursor_x'] as int,
      cursorY: json['cursor_y'] as int,
      monitorId: json['monitor_id'] as int,
      captureWidth: json['capture_width'] as int,
      captureHeight: json['capture_height'] as int,
      data: json['data'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'cursor_x': cursorX,
      'cursor_y': cursorY,
      'monitor_id': monitorId,
      'capture_width': captureWidth,
      'capture_height': captureHeight,
      'data': data,
    };
  }
}

/// Screen frame request from client to server (mobile → PC)
/// Client sends viewport dimensions and zoom level, server calculates capture size
class ScreenFrameRequest {
  final int viewportWidth;       // Client's display area width
  final int viewportHeight;      // Client's display area height
  final double zoomLevel;        // Zoom level: 0.1 (zoomed out) to 5.0 (zoomed in)

  ScreenFrameRequest({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.zoomLevel,
  });

  /// Convert to JSON for WebSocket transmission
  Map<String, dynamic> toJson() {
    return {
      'viewport_width': viewportWidth,
      'viewport_height': viewportHeight,
      'zoom_level': zoomLevel,
    };
  }
}

/// Mouse command payloads
@JsonSerializable()
class MouseMovePayload {
  final int dx;
  final int dy;
  
  const MouseMovePayload({required this.dx, required this.dy});
  
  factory MouseMovePayload.fromJson(Map<String, dynamic> json) =>
      _$MouseMovePayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$MouseMovePayloadToJson(this);
}

@JsonSerializable()
class MouseClickPayload {
  final MouseButton button;
  final ButtonState state;
  
  const MouseClickPayload({required this.button, required this.state});
  
  factory MouseClickPayload.fromJson(Map<String, dynamic> json) =>
      _$MouseClickPayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$MouseClickPayloadToJson(this);
}

@JsonSerializable()
class MouseScrollPayload {
  final int dx;
  final int dy;
  
  const MouseScrollPayload({required this.dx, required this.dy});
  
  factory MouseScrollPayload.fromJson(Map<String, dynamic> json) =>
      _$MouseScrollPayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$MouseScrollPayloadToJson(this);
}

/// Keyboard command payloads
@JsonSerializable()
class KeyPressPayload {
  final String key;
  
  const KeyPressPayload({required this.key});
  
  factory KeyPressPayload.fromJson(Map<String, dynamic> json) =>
      _$KeyPressPayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$KeyPressPayloadToJson(this);
}

@JsonSerializable()
class TypeTextPayload {
  final String text;
  
  const TypeTextPayload({required this.text});
  
  factory TypeTextPayload.fromJson(Map<String, dynamic> json) =>
      _$TypeTextPayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$TypeTextPayloadToJson(this);
}

/// Media command payloads
@JsonSerializable()
class MediaPayload {
  final MediaAction action;
  
  const MediaPayload({required this.action});
  
  factory MediaPayload.fromJson(Map<String, dynamic> json) =>
      _$MediaPayloadFromJson(json);
  
  Map<String, dynamic> toJson() => _$MediaPayloadToJson(this);
}

/// Mouse button enumeration
enum MouseButton {
  left,
  right,
  middle,
}

/// Button state enumeration
enum ButtonState {
  press,
  release,
}

/// Media action enumeration
enum MediaAction {
  playPause,
  nextTrack,
  prevTrack,
  volumeUp,
  volumeDown,
  mute,
}
