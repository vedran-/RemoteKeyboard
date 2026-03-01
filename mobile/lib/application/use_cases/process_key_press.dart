/// Process Key Press Use Case
///
/// Transforms keyboard input into keyboard commands.

import '../../domain/entities/command.dart';

/// Process keyboard input and convert to commands
class ProcessKeyPress {
  /// Process a single key press
  Command processKey(String key) {
    final normalizedKey = _normalizeKey(key);
    return Command.keyPress(normalizedKey);
  }
  
  /// Process text input (optimized for typing)
  Command processText(String text) {
    return Command.typeText(text);
  }
  
  /// Process special key
  Command processSpecialKey(SpecialKey key) {
    return Command.keyPress(key.value);
  }
  
  /// Normalize key name for PC
  String _normalizeKey(String key) {
    // Handle special keys
    final specialKeys = {
      'Enter': 'Enter',
      'Backspace': 'Backspace',
      'Tab': 'Tab',
      'Escape': 'Escape',
      'Space': ' ',
      'ArrowUp': 'Up',
      'ArrowDown': 'Down',
      'ArrowLeft': 'Left',
      'ArrowRight': 'Right',
    };
    
    if (specialKeys.containsKey(key)) {
      return specialKeys[key]!;
    }
    
    // For regular characters, use uppercase for single chars
    if (key.length == 1) {
      return key.toUpperCase();
    }
    
    return key;
  }
}

/// Special key enumeration
enum SpecialKey {
  enter('Enter'),
  backspace('Backspace'),
  tab('Tab'),
  escape('Escape'),
  space(' '),
  arrowUp('Up'),
  arrowDown('Down'),
  arrowLeft('Left'),
  arrowRight('Right'),
  delete('Delete'),
  home('Home'),
  end('End'),
  pageUp('PageUp'),
  pageDown('PageDown'),
  f1('F1'),
  f2('F2'),
  f3('F3'),
  f4('F4'),
  f5('F5'),
  f6('F6'),
  f7('F7'),
  f8('F8'),
  f9('F9'),
  f10('F10'),
  f11('F11'),
  f12('F12'),
  ;
  
  final String value;
  const SpecialKey(this.value);
}
