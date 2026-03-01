/// Tests for Command Entity
///
/// Verifies command creation, JSON serialization, and factory methods.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/domain/domain.dart';

void main() {
  group('Command', () {
    group('Mouse Commands', () {
      test('mouseMove creates correct command', () {
        const dx = 10;
        const dy = -5;

        final command = Command.mouseMove(dx, dy);

        expect(command.type, CommandType.mouse);
        expect(command.payload, isA<MouseMovePayload>());
        expect((command.payload as MouseMovePayload).dx, dx);
        expect((command.payload as MouseMovePayload).dy, dy);
      });

      test('mouseClick creates correct command', () {
        final command = Command.mouseClick(
          MouseButton.left,
          ButtonState.press,
        );

        expect(command.type, CommandType.mouse);
        expect(command.payload, isA<MouseClickPayload>());
        final payload = command.payload as MouseClickPayload;
        expect(payload.button, MouseButton.left);
        expect(payload.state, ButtonState.press);
      });

      test('mouseScroll creates correct command', () {
        const dx = 0;
        const dy = 3;

        final command = Command.mouseScroll(dx, dy);

        expect(command.type, CommandType.mouse);
        expect(command.payload, isA<MouseScrollPayload>());
        expect((command.payload as MouseScrollPayload).dx, dx);
        expect((command.payload as MouseScrollPayload).dy, dy);
      });
    });

    group('Keyboard Commands', () {
      test('keyPress creates correct command', () {
        const key = 'Enter';

        final command = Command.keyPress(key);

        expect(command.type, CommandType.keyboard);
        expect(command.payload, isA<KeyPressPayload>());
        expect((command.payload as KeyPressPayload).key, key);
      });

      test('typeText creates correct command', () {
        const text = 'Hello, World!';

        final command = Command.typeText(text);

        expect(command.type, CommandType.keyboard);
        expect(command.payload, isA<TypeTextPayload>());
        expect((command.payload as TypeTextPayload).text, text);
      });
    });

    group('Media Commands', () {
      test('mediaKey creates correct command for playPause', () {
        final command = Command.mediaKey(MediaAction.playPause);

        expect(command.type, CommandType.media);
        expect(command.payload, isA<MediaPayload>());
        expect((command.payload as MediaPayload).action, MediaAction.playPause);
      });

      test('mediaKey creates correct command for volumeUp', () {
        final command = Command.mediaKey(MediaAction.volumeUp);

        expect(command.type, CommandType.media);
        expect(command.payload, isA<MediaPayload>());
        expect((command.payload as MediaPayload).action, MediaAction.volumeUp);
      });

      test('mediaKey creates correct command for nextTrack', () {
        final command = Command.mediaKey(MediaAction.nextTrack);

        expect(command.type, CommandType.media);
        expect(command.payload, isA<MediaPayload>());
        expect((command.payload as MediaPayload).action, MediaAction.nextTrack);
      });
    });

    group('JSON Serialization', () {
      test('mouseMove serializes to JSON correctly', () {
        final command = Command.mouseMove(10, -5);

        final json = command.toJson();

        expect(json['type'], 'mouse');
        expect(json['payload'], isA<Map<String, dynamic>>());
        expect(json['payload']['dx'], 10);
        expect(json['payload']['dy'], -5);
      });

      test('keyPress serializes to JSON correctly', () {
        final command = Command.keyPress('A');

        final json = command.toJson();

        expect(json['type'], 'keyboard');
        expect(json['payload'], isA<Map<String, dynamic>>());
        expect(json['payload']['key'], 'A');
      });

      test('mediaKey serializes to JSON correctly', () {
        final command = Command.mediaKey(MediaAction.playPause);

        final json = command.toJson();

        expect(json['type'], 'media');
        expect(json['payload'], isA<Map<String, dynamic>>());
        expect(json['payload']['action'], 'playPause');
      });

      test('fromJson deserializes mouse command', () {
        final json = {
          'type': 'mouse',
          'payload': {'dx': 15, 'dy': -10},
        };

        final command = Command.fromJson(json);

        expect(command.type, CommandType.mouse);
        expect(command.payload, isA<Map<String, dynamic>>());
      });

      test('fromJson deserializes keyboard command', () {
        final json = {
          'type': 'keyboard',
          'payload': {'key': 'Enter'},
        };

        final command = Command.fromJson(json);

        expect(command.type, CommandType.keyboard);
        expect(command.payload, isA<Map<String, dynamic>>());
      });

      test('fromJson deserializes media command', () {
        final json = {
          'type': 'media',
          'payload': {'action': 'volumeUp'},
        };

        final command = Command.fromJson(json);

        expect(command.type, CommandType.media);
        expect(command.payload, isA<Map<String, dynamic>>());
      });

      test('fromJson with unknown type defaults to mouse', () {
        final json = {
          'type': 'unknown_type',
          'payload': {},
        };

        final command = Command.fromJson(json);

        expect(command.type, CommandType.mouse);
      });
    });

    group('Payload Serialization', () {
      test('MouseMovePayload serializes and deserializes', () {
        const payload = MouseMovePayload(dx: 20, dy: -15);

        final json = payload.toJson();
        final deserialized = MouseMovePayload.fromJson(json);

        expect(deserialized.dx, 20);
        expect(deserialized.dy, -15);
      });

      test('MouseClickPayload serializes and deserializes', () {
        const payload = MouseClickPayload(
          button: MouseButton.right,
          state: ButtonState.release,
        );

        final json = payload.toJson();
        final deserialized = MouseClickPayload.fromJson(json);

        expect(deserialized.button, MouseButton.right);
        expect(deserialized.state, ButtonState.release);
      });

      test('MouseScrollPayload serializes and deserializes', () {
        const payload = MouseScrollPayload(dx: 5, dy: 10);

        final json = payload.toJson();
        final deserialized = MouseScrollPayload.fromJson(json);

        expect(deserialized.dx, 5);
        expect(deserialized.dy, 10);
      });

      test('KeyPressPayload serializes and deserializes', () {
        const payload = KeyPressPayload(key: 'Backspace');

        final json = payload.toJson();
        final deserialized = KeyPressPayload.fromJson(json);

        expect(deserialized.key, 'Backspace');
      });

      test('TypeTextPayload serializes and deserializes', () {
        const payload = TypeTextPayload(text: 'Test message');

        final json = payload.toJson();
        final deserialized = TypeTextPayload.fromJson(json);

        expect(deserialized.text, 'Test message');
      });

      test('MediaPayload serializes and deserializes', () {
        const payload = MediaPayload(action: MediaAction.prevTrack);

        final json = payload.toJson();
        final deserialized = MediaPayload.fromJson(json);

        expect(deserialized.action, MediaAction.prevTrack);
      });
    });
  });

  group('CommandType Enum', () {
    test('has correct number of types', () {
      expect(CommandType.values.length, 4);
    });

    test('has expected type names', () {
      expect(CommandType.values.map((e) => e.name), contains('mouse'));
      expect(CommandType.values.map((e) => e.name), contains('keyboard'));
      expect(CommandType.values.map((e) => e.name), contains('media'));
      expect(CommandType.values.map((e) => e.name), contains('custom'));
    });
  });

  group('MouseButton Enum', () {
    test('has correct number of buttons', () {
      expect(MouseButton.values.length, 3);
    });

    test('has expected button names', () {
      expect(MouseButton.values.map((e) => e.name), contains('left'));
      expect(MouseButton.values.map((e) => e.name), contains('right'));
      expect(MouseButton.values.map((e) => e.name), contains('middle'));
    });
  });

  group('ButtonState Enum', () {
    test('has correct number of states', () {
      expect(ButtonState.values.length, 2);
    });

    test('has expected state names', () {
      expect(ButtonState.values.map((e) => e.name), contains('press'));
      expect(ButtonState.values.map((e) => e.name), contains('release'));
    });
  });

  group('MediaAction Enum', () {
    test('has correct number of actions', () {
      expect(MediaAction.values.length, 6);
    });

    test('has expected action names', () {
      expect(MediaAction.values.map((e) => e.name), contains('playPause'));
      expect(MediaAction.values.map((e) => e.name), contains('nextTrack'));
      expect(MediaAction.values.map((e) => e.name), contains('prevTrack'));
      expect(MediaAction.values.map((e) => e.name), contains('volumeUp'));
      expect(MediaAction.values.map((e) => e.name), contains('volumeDown'));
      expect(MediaAction.values.map((e) => e.name), contains('mute'));
    });
  });
}
