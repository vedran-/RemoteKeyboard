/// Process Media Key Use Case
///
/// Transforms media button presses into media commands.

import '../../domain/entities/command.dart';

/// Process media key input and convert to commands
class ProcessMediaKey {
  /// Process media button press
  Command process(MediaAction action) {
    return Command.mediaKey(action);
  }
  
  /// Process play/pause toggle
  Command playPause() {
    return Command.mediaKey(MediaAction.playPause);
  }
  
  /// Process next track
  Command nextTrack() {
    return Command.mediaKey(MediaAction.nextTrack);
  }
  
  /// Process previous track
  Command prevTrack() {
    return Command.mediaKey(MediaAction.prevTrack);
  }
  
  /// Process volume up
  Command volumeUp() {
    return Command.mediaKey(MediaAction.volumeUp);
  }
  
  /// Process volume down
  Command volumeDown() {
    return Command.mediaKey(MediaAction.volumeDown);
  }
  
  /// Process mute
  Command mute() {
    return Command.mediaKey(MediaAction.mute);
  }
  
  /// Parse action from string
  MediaAction? parseAction(String actionString) {
    switch (actionString.toLowerCase()) {
      case 'play_pause':
      case 'playpause':
      case 'play/pause':
        return MediaAction.playPause;
      case 'next':
      case 'nexttrack':
      case 'next_track':
        return MediaAction.nextTrack;
      case 'prev':
      case 'prevtrack':
      case 'prev_track':
      case 'previous':
        return MediaAction.prevTrack;
      case 'vol_up':
      case 'volup':
      case 'volumeup':
      case 'volume_up':
        return MediaAction.volumeUp;
      case 'vol_down':
      case 'voldown':
      case 'volumedown':
      case 'volume_down':
        return MediaAction.volumeDown;
      case 'mute':
        return MediaAction.mute;
      default:
        return null;
    }
  }
}
