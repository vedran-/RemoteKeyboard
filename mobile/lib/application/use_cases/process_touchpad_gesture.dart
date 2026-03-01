/// Process Touchpad Gesture Use Case
///
/// Transforms touchpad gestures into mouse commands.

import '../../domain/entities/command.dart';

/// Sensitivity multiplier for touchpad
typedef Sensitivity = double;

/// Process touchpad gesture and convert to mouse command
class ProcessTouchpadGesture {
  /// Convert pan gesture delta to mouse move command
  Command processPan({
    required double dx,
    required double dy,
    required Sensitivity sensitivity,
  }) {
    // Apply sensitivity multiplier
    final scaledDx = (dx * sensitivity).round();
    final scaledDy = (dy * sensitivity).round();
    
    return Command.mouseMove(scaledDx, scaledDy);
  }
  
  /// Process tap gesture
  Command processTap({bool isRightClick = false}) {
    final button = isRightClick ? MouseButton.right : MouseButton.left;
    return Command.mouseClick(button, ButtonState.press);
  }
  
  /// Process tap release
  Command processTapRelease({bool isRightClick = false}) {
    final button = isRightClick ? MouseButton.right : MouseButton.left;
    return Command.mouseClick(button, ButtonState.release);
  }
  
  /// Process scroll gesture
  Command processScroll({
    required double dx,
    required double dy,
    required Sensitivity sensitivity,
  }) {
    // Scroll sensitivity is typically higher
    final scrollSensitivity = sensitivity * 0.5;
    final scaledDx = (dx * scrollSensitivity).round();
    final scaledDy = (dy * scrollSensitivity).round();
    
    return Command.mouseScroll(scaledDx, scaledDy);
  }
  
  /// Calculate sensitivity multiplier from enum value
  static Sensitivity getSensitivityMultiplier(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 0.5;
      case 'normal':
        return 1.0;
      case 'high':
        return 1.5;
      case 'very high':
        return 2.0;
      default:
        return 1.0;
    }
  }
}
