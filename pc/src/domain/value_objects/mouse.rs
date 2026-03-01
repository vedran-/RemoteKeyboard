//! Mouse Value Objects
//!
//! Immutable value objects for mouse-related commands.

use serde::{Deserialize, Serialize};

/// Mouse button identifier
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum MouseButton {
    /// Left mouse button (primary)
    #[serde(rename = "left")]
    Left,
    
    /// Right mouse button (secondary)
    #[serde(rename = "right")]
    Right,
    
    /// Middle mouse button (wheel click)
    #[serde(rename = "middle")]
    Middle,
}

impl MouseButton {
    /// Get the button name as a string
    pub fn as_str(&self) -> &'static str {
        match self {
            MouseButton::Left => "left",
            MouseButton::Right => "right",
            MouseButton::Middle => "middle",
        }
    }
    
    /// Parse from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "left" => Some(MouseButton::Left),
            "right" => Some(MouseButton::Right),
            "middle" => Some(MouseButton::Middle),
            _ => None,
        }
    }
}

impl Default for MouseButton {
    fn default() -> Self {
        MouseButton::Left
    }
}

/// Button state (press or release)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ButtonState {
    /// Button is pressed
    #[serde(rename = "press")]
    Press,
    
    /// Button is released
    #[serde(rename = "release")]
    Release,
}

impl ButtonState {
    /// Get the state name as a string
    pub fn as_str(&self) -> &'static str {
        match self {
            ButtonState::Press => "press",
            ButtonState::Release => "release",
        }
    }
    
    /// Check if this is a press state
    pub fn is_press(&self) -> bool {
        matches!(self, ButtonState::Press)
    }
    
    /// Check if this is a release state
    pub fn is_release(&self) -> bool {
        matches!(self, ButtonState::Release)
    }
    
    /// Parse from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "press" => Some(ButtonState::Press),
            "release" => Some(ButtonState::Release),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_mouse_button_as_str() {
        assert_eq!(MouseButton::Left.as_str(), "left");
        assert_eq!(MouseButton::Right.as_str(), "right");
        assert_eq!(MouseButton::Middle.as_str(), "middle");
    }
    
    #[test]
    fn test_mouse_button_from_str() {
        assert_eq!(MouseButton::from_str("left"), Some(MouseButton::Left));
        assert_eq!(MouseButton::from_str("LEFT"), Some(MouseButton::Left));
        assert_eq!(MouseButton::from_str("Right"), Some(MouseButton::Right));
        assert_eq!(MouseButton::from_str("middle"), Some(MouseButton::Middle));
        assert_eq!(MouseButton::from_str("invalid"), None);
    }
    
    #[test]
    fn test_mouse_button_default() {
        assert_eq!(MouseButton::default(), MouseButton::Left);
    }
    
    #[test]
    fn test_mouse_button_equality() {
        assert_eq!(MouseButton::Left, MouseButton::Left);
        assert_ne!(MouseButton::Left, MouseButton::Right);
    }
    
    #[test]
    fn test_button_state_as_str() {
        assert_eq!(ButtonState::Press.as_str(), "press");
        assert_eq!(ButtonState::Release.as_str(), "release");
    }
    
    #[test]
    fn test_button_state_from_str() {
        assert_eq!(ButtonState::from_str("press"), Some(ButtonState::Press));
        assert_eq!(ButtonState::from_str("PRESS"), Some(ButtonState::Press));
        assert_eq!(ButtonState::from_str("Release"), Some(ButtonState::Release));
        assert_eq!(ButtonState::from_str("invalid"), None);
    }
    
    #[test]
    fn test_button_state_predicates() {
        assert!(ButtonState::Press.is_press());
        assert!(!ButtonState::Press.is_release());
        assert!(!ButtonState::Release.is_press());
        assert!(ButtonState::Release.is_release());
    }
    
    #[test]
    fn test_button_state_equality() {
        assert_eq!(ButtonState::Press, ButtonState::Press);
        assert_ne!(ButtonState::Press, ButtonState::Release);
    }
    
    #[test]
    fn test_mouse_button_serialization() {
        let left = MouseButton::Left;
        let json = serde_json::to_string(&left).unwrap();
        assert_eq!(json, "\"left\"");
        
        let deserialized: MouseButton = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, MouseButton::Left);
    }
    
    #[test]
    fn test_button_state_serialization() {
        let press = ButtonState::Press;
        let json = serde_json::to_string(&press).unwrap();
        assert_eq!(json, "\"press\"");
        
        let deserialized: ButtonState = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, ButtonState::Press);
    }
}
