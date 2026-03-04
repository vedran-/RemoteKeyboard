/// Tests for Command Entity
///
/// Verifies command creation and JSON serialization according to the flat protocol spec.

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/domain/domain.dart';

void main() {
  group('Command', () {
    group('Mouse Commands', () {
      test('mouseMove creates correct command', () {
        const dx = 10;
        const dy = -5;

        final command = Command.mouseMove(dx, dy);

        expect(command.type, 'mouse-move');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['dx'], dx);
        expect(command.payload!['dy'], dy);
      });

      test('mouseMove serializes to flat JSON', () {
        final command = Command.mouseMove(10, -5);
        final json = command.toJson();

        expect(json['type'], 'mouse-move');
        expect(json['dx'], 10);
        expect(json['dy'], -5);
        expect(json['payload'], isNull);
      });

      test('mouseClick creates correct command', () {
        final command = Command.mouseClick(
          MouseButton.left,
          ButtonState.press,
        );

        expect(command.type, 'mouse-click');
        expect(command.payload, isA<Map<String, dynamic>>());
        final payload = command.payload!;
        expect(payload['button'], 'left');
        expect(payload['state'], 'press');
      });

      test('mouseClick serializes to flat JSON', () {
        final command = Command.mouseClick(MouseButton.right, ButtonState.release);
        final json = command.toJson();

        expect(json['type'], 'mouse-click');
        expect(json['button'], 'right');
        expect(json['state'], 'release');
      });

      test('mouseScroll creates correct command', () {
        const dx = 0;
        const dy = 3;

        final command = Command.mouseScroll(dx, dy);

        expect(command.type, 'mouse-scroll');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['dx'], dx);
        expect(command.payload!['dy'], dy);
      });

      test('mouseScroll serializes to flat JSON', () {
        final command = Command.mouseScroll(0, 120);
        final json = command.toJson();

        expect(json['type'], 'mouse-scroll');
        expect(json['dx'], 0);
        expect(json['dy'], 120);
      });
    });

    group('Keyboard Commands', () {
      test('keyPress creates correct command', () {
        const key = 'Enter';

        final command = Command.keyPress(key);

        expect(command.type, 'key-press');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['key'], key);
      });

      test('keyPress serializes to flat JSON', () {
        final command = Command.keyPress('A');
        final json = command.toJson();

        expect(json['type'], 'key-press');
        expect(json['key'], 'A');
      });

      test('typeText creates correct command', () {
        const text = 'Hello, World!';

        final command = Command.typeText(text);

        expect(command.type, 'type-text');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['text'], text);
      });

      test('typeText serializes to flat JSON', () {
        final command = Command.typeText('Hello');
        final json = command.toJson();

        expect(json['type'], 'type-text');
        expect(json['text'], 'Hello');
      });
    });

    group('Media Commands', () {
      test('mediaKey creates correct command for playPause', () {
        final command = Command.mediaKey(MediaAction.playPause);

        expect(command.type, 'media-key');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['key'], 'play_pause');
      });

      test('mediaKey serializes to flat JSON for playPause', () {
        final command = Command.mediaKey(MediaAction.playPause);
        final json = command.toJson();

        expect(json['type'], 'media-key');
        expect(json['key'], 'play_pause');
      });

      test('mediaKey serializes correctly for all actions', () {
        expect(Command.mediaKey(MediaAction.playPause).toJson()['key'], 'play_pause');
        expect(Command.mediaKey(MediaAction.nextTrack).toJson()['key'], 'next');
        expect(Command.mediaKey(MediaAction.prevTrack).toJson()['key'], 'prev');
        expect(Command.mediaKey(MediaAction.volumeUp).toJson()['key'], 'vol_up');
        expect(Command.mediaKey(MediaAction.volumeDown).toJson()['key'], 'vol_down');
        expect(Command.mediaKey(MediaAction.mute).toJson()['key'], 'mute');
      });
    });

    group('Stream Control Commands', () {
      test('streamStart creates correct command', () {
        final command = Command.streamStart(width: 800, height: 600, zoom: 1.5);

        expect(command.type, 'stream-start');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['width'], 800);
        expect(command.payload!['height'], 600);
        expect(command.payload!['zoom'], 1.5);
      });

      test('streamStart serializes to flat JSON', () {
        final command = Command.streamStart(width: 800, height: 600, zoom: 1.5);
        final json = command.toJson();

        expect(json['type'], 'stream-start');
        expect(json['width'], 800);
        expect(json['height'], 600);
        expect(json['zoom'], 1.5);
      });

      test('streamUpdate creates correct command', () {
        final command = Command.streamUpdate(width: 400, height: 300, zoom: 2.0);

        expect(command.type, 'stream-update');
        expect(command.payload, isA<Map<String, dynamic>>());
        expect(command.payload!['width'], 400);
        expect(command.payload!['height'], 300);
        expect(command.payload!['zoom'], 2.0);
      });

      test('streamUpdate serializes to flat JSON', () {
        final command = Command.streamUpdate(width: 400, height: 300, zoom: 2.0);
        final json = command.toJson();

        expect(json['type'], 'stream-update');
        expect(json['width'], 400);
        expect(json['height'], 300);
        expect(json['zoom'], 2.0);
      });

      test('streamStop creates correct command', () {
        final command = Command.streamStop();

        expect(command.type, 'stream-stop');
        expect(command.payload, isNull);
      });

      test('streamStop serializes to flat JSON', () {
        final command = Command.streamStop();
        final json = command.toJson();

        expect(json['type'], 'stream-stop');
        expect(json.length, 1); // Only 'type' field
      });
    });

    group('JSON Deserialization', () {
      test('fromJson deserializes mouse-move', () {
        final json = {'type': 'mouse-move', 'dx': 15, 'dy': -10};
        final command = Command.fromJson(json);

        expect(command.type, 'mouse-move');
        expect(command.payload!['dx'], 15);
        expect(command.payload!['dy'], -10);
      });

      test('fromJson deserializes mouse-click', () {
        final json = {'type': 'mouse-click', 'button': 'left', 'state': 'press'};
        final command = Command.fromJson(json);

        expect(command.type, 'mouse-click');
        expect(command.payload!['button'], 'left');
        expect(command.payload!['state'], 'press');
      });

      test('fromJson deserializes media-key', () {
        final json = {'type': 'media-key', 'key': 'play_pause'};
        final command = Command.fromJson(json);

        expect(command.type, 'media-key');
        expect(command.payload!['key'], 'play_pause');
      });

      test('fromJson deserializes stream-start', () {
        final json = {'type': 'stream-start', 'width': 800, 'height': 600, 'zoom': 1.5};
        final command = Command.fromJson(json);

        expect(command.type, 'stream-start');
        expect(command.payload!['width'], 800);
        expect(command.payload!['height'], 600);
        expect(command.payload!['zoom'], 1.5);
      });

      test('fromJson deserializes stream-stop', () {
        final json = {'type': 'stream-stop'};
        final command = Command.fromJson(json);

        expect(command.type, 'stream-stop');
        expect(command.payload, isNull);
      });
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

    test('serverValue returns correct snake_case values', () {
      expect(MediaAction.playPause.serverValue, 'play_pause');
      expect(MediaAction.nextTrack.serverValue, 'next');
      expect(MediaAction.prevTrack.serverValue, 'prev');
      expect(MediaAction.volumeUp.serverValue, 'vol_up');
      expect(MediaAction.volumeDown.serverValue, 'vol_down');
      expect(MediaAction.mute.serverValue, 'mute');
    });
  });
}
