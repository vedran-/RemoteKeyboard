/// Command Entity
///
/// Commands represent input actions to be sent to the PC.
/// Implements the flat JSON protocol as specified in implementation_plan.md.
///
/// Protocol format (Client → Server):
/// ```json
/// { "type": "mouse-move", "dx": 10, "dy": -5 }
/// { "type": "mouse-click", "button": "left", "state": "press" }
/// { "type": "mouse-scroll", "dx": 0, "dy": 120 }
/// { "type": "key-press", "key": "A" }
/// { "type": "type-text", "text": "Hello World" }
/// { "type": "media-key", "key": "play_pause" }
/// { "type": "stream-start", "width": 800, "height": 600, "zoom": 1.3 }
/// { "type": "stream-update", "width": 800, "height": 600, "zoom": 2.0 }
/// { "type": "stream-stop" }
/// ```

import 'dart:typed_data';

/// Core Command entity - represents an input action to send to PC
class Command {
  final String type;
  final Map<String, dynamic>? payload;

  const Command({
    required this.type,
    this.payload,
  });

  /// Mouse move command
  /// JSON: { "type": "mouse-move", "dx": 10, "dy": -5 }
  factory Command.mouseMove(int dx, int dy) {
    return Command(
      type: 'mouse-move',
      payload: {'dx': dx, 'dy': dy},
    );
  }

  /// Mouse click command
  /// JSON: { "type": "mouse-click", "button": "left", "state": "press" }
  factory Command.mouseClick(MouseButton button, ButtonState state) {
    return Command(
      type: 'mouse-click',
      payload: {'button': button.name, 'state': state.name},
    );
  }

  /// Mouse scroll command
  /// JSON: { "type": "mouse-scroll", "dx": 0, "dy": 120 }
  factory Command.mouseScroll(int dx, int dy) {
    return Command(
      type: 'mouse-scroll',
      payload: {'dx': dx, 'dy': dy},
    );
  }

  /// Key press command
  /// JSON: { "type": "key-press", "key": "A" }
  factory Command.keyPress(String key) {
    return Command(
      type: 'key-press',
      payload: {'key': key},
    );
  }

  /// Type text command
  /// JSON: { "type": "type-text", "text": "Hello World" }
  factory Command.typeText(String text) {
    return Command(
      type: 'type-text',
      payload: {'text': text},
    );
  }

  /// Media key command
  /// JSON: { "type": "media-key", "key": "play_pause" }
  factory Command.mediaKey(MediaAction action) {
    return Command(
      type: 'media-key',
      payload: {'key': action.serverValue},
    );
  }

  /// Stream start command
  /// JSON: { "type": "stream-start", "width": 800, "height": 600, "zoom": 1.3 }
  factory Command.streamStart({required int width, required int height, required double zoom}) {
    return Command(
      type: 'stream-start',
      payload: {'width': width, 'height': height, 'zoom': zoom},
    );
  }

  /// Stream update command
  /// JSON: { "type": "stream-update", "width": 800, "height": 600, "zoom": 2.0 }
  factory Command.streamUpdate({required int width, required int height, required double zoom}) {
    return Command(
      type: 'stream-update',
      payload: {'width': width, 'height': height, 'zoom': zoom},
    );
  }

  /// Stream stop command
  /// JSON: { "type": "stream-stop" }
  factory Command.streamStop() {
    return const Command(
      type: 'stream-stop',
      payload: null,
    );
  }

  /// Convert to JSON for WebSocket transmission
  /// Returns flat JSON format as per protocol spec
  Map<String, dynamic> toJson() {
    if (payload == null) {
      return {'type': type};
    }
    return {'type': type, ...payload!};
  }

  /// Create from JSON
  factory Command.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    // Copy all fields except 'type' into payload
    final payload = Map<String, dynamic>.from(json)..remove('type');
    return Command(
      type: type,
      payload: payload.isEmpty ? null : payload,
    );
  }
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
  mute;

  /// Server expects snake_case values
  String get serverValue {
    switch (this) {
      case MediaAction.playPause:
        return 'play_pause';
      case MediaAction.nextTrack:
        return 'next';
      case MediaAction.prevTrack:
        return 'prev';
      case MediaAction.volumeUp:
        return 'vol_up';
      case MediaAction.volumeDown:
        return 'vol_down';
      case MediaAction.mute:
        return 'mute';
    }
  }
}

/// Screen frame for streaming from PC
/// Note: In the new protocol, screen frames are sent as binary (raw JPEG bytes),
/// not as JSON with base64. This class is kept for internal use only.
class ScreenFrame {
  final int captureWidth;
  final int captureHeight;
  final Uint8List jpegData;  // Raw JPEG bytes (not base64)

  ScreenFrame({
    required this.captureWidth,
    required this.captureHeight,
    required this.jpegData,
  });

  /// Create from binary JPEG data
  factory ScreenFrame.fromBinary(Uint8List jpegData) {
    // Width/height will be extracted from JPEG headers by the image decoder
    // For now, we store the raw data
    return ScreenFrame(
      captureWidth: 0,  // Will be determined from decoded image
      captureHeight: 0,
      jpegData: jpegData,
    );
  }
}
