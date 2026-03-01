//! Keyboard Value Objects
//!
//! Immutable value objects for keyboard-related commands.

use serde::{Deserialize, Serialize};

/// Key code representing a physical key on the keyboard
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum KeyCode {
    /// Letters A-Z
    Letter(char),
    
    /// Numbers 0-9
    Number(u8),
    
    /// Function keys F1-F12
    Function(u8),
    
    /// Control keys
    Control,
    Alt,
    Shift,
    Meta, // Windows key on Windows, Command on macOS
    
    /// Navigation keys
    Enter,
    Backspace,
    Tab,
    Escape,
    Space,
    
    /// Arrow keys
    ArrowUp,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
    
    /// Editing keys
    Delete,
    Insert,
    Home,
    End,
    PageUp,
    PageDown,
    
    /// Symbol keys
    Plus,
    Minus,
    Equal,
    BracketLeft,
    BracketRight,
    Semicolon,
    Quote,
    Backquote,
    Backslash,
    Comma,
    Period,
    Slash,
    
    /// Numpad keys
    Numpad0,
    Numpad1,
    Numpad2,
    Numpad3,
    Numpad4,
    Numpad5,
    Numpad6,
    Numpad7,
    Numpad8,
    Numpad9,
    NumpadAdd,
    NumpadSubtract,
    NumpadMultiply,
    NumpadDivide,
    NumpadDecimal,
    NumpadEnter,
    
    /// Other keys
    CapsLock,
    ScrollLock,
    NumLock,
    PrintScreen,
    Pause,
    
    /// Media keys (separate from MediaCommand for flexibility)
    MediaPlayPause,
    MediaNext,
    MediaPrev,
    MediaStop,
    
    /// Unknown or custom key
    Unknown(String),
}

impl KeyCode {
    /// Parse a key code from a string
    pub fn from_str(s: &str) -> Self {
        // Single character keys
        if s.len() == 1 {
            let c = s.chars().next().unwrap();
            if c.is_ascii_alphabetic() {
                return KeyCode::Letter(c.to_ascii_uppercase());
            }
            if c.is_ascii_digit() {
                return KeyCode::Number(c.to_digit(10).unwrap() as u8);
            }
        }
        
        // Named keys
        match s.to_lowercase().as_str() {
            "enter" => KeyCode::Enter,
            "backspace" => KeyCode::Backspace,
            "tab" => KeyCode::Tab,
            "escape" => KeyCode::Escape,
            "space" => KeyCode::Space,
            
            "arrowup" | "arrow_up" | "up" => KeyCode::ArrowUp,
            "arrowdown" | "arrow_down" | "down" => KeyCode::ArrowDown,
            "arrowleft" | "arrow_left" | "left" => KeyCode::ArrowLeft,
            "arrowright" | "arrow_right" | "right" => KeyCode::ArrowRight,
            
            "delete" => KeyCode::Delete,
            "insert" => KeyCode::Insert,
            "home" => KeyCode::Home,
            "end" => KeyCode::End,
            "pageup" | "page_up" => KeyCode::PageUp,
            "pagedown" | "page_down" => KeyCode::PageDown,
            
            "plus" => KeyCode::Plus,
            "minus" => KeyCode::Minus,
            "equal" => KeyCode::Equal,
            "bracketleft" | "bracket_left" | "[" => KeyCode::BracketLeft,
            "bracketright" | "bracket_right" | "]" => KeyCode::BracketRight,
            "semicolon" | ";" => KeyCode::Semicolon,
            "quote" | "'" => KeyCode::Quote,
            "backquote" | "`" => KeyCode::Backquote,
            "backslash" | "\\" => KeyCode::Backslash,
            "comma" | "," => KeyCode::Comma,
            "period" | "." => KeyCode::Period,
            "slash" | "/" => KeyCode::Slash,
            
            "control" => KeyCode::Control,
            "alt" => KeyCode::Alt,
            "shift" => KeyCode::Shift,
            "meta" | "windows" | "command" => KeyCode::Meta,
            
            "capslock" | "caps_lock" => KeyCode::CapsLock,
            "scrolllock" | "scroll_lock" => KeyCode::ScrollLock,
            "numlock" | "num_lock" => KeyCode::NumLock,
            "printscreen" | "print_screen" => KeyCode::PrintScreen,
            "pause" => KeyCode::Pause,
            
            // Function keys
            s if s.starts_with('f') && s.len() <= 3 => {
                if let Ok(num) = s[1..].parse::<u8>() {
                    if num >= 1 && num <= 12 {
                        return KeyCode::Function(num);
                    }
                }
                KeyCode::Unknown(s.to_string())
            }
            
            // Numpad keys
            "numpad0" => KeyCode::Numpad0,
            "numpad1" => KeyCode::Numpad1,
            "numpad2" => KeyCode::Numpad2,
            "numpad3" => KeyCode::Numpad3,
            "numpad4" => KeyCode::Numpad4,
            "numpad5" => KeyCode::Numpad5,
            "numpad6" => KeyCode::Numpad6,
            "numpad7" => KeyCode::Numpad7,
            "numpad8" => KeyCode::Numpad8,
            "numpad9" => KeyCode::Numpad9,
            "numpadadd" | "numpad_add" => KeyCode::NumpadAdd,
            "numpadsubtract" | "numpad_subtract" => KeyCode::NumpadSubtract,
            "numpadmultiply" | "numpad_multiply" => KeyCode::NumpadMultiply,
            "numpaddivide" | "numpad_divide" => KeyCode::NumpadDivide,
            "numpaddecimal" | "numpad_decimal" => KeyCode::NumpadDecimal,
            "numpadenter" | "numpad_enter" => KeyCode::NumpadEnter,
            
            // Media keys
            "medioplaypause" | "media_play_pause" | "play_pause" => KeyCode::MediaPlayPause,
            "medianext" | "media_next" | "next" => KeyCode::MediaNext,
            "mediaprev" | "media_prev" | "prev" => KeyCode::MediaPrev,
            "mediastop" | "media_stop" => KeyCode::MediaStop,
            
            _ => KeyCode::Unknown(s.to_string()),
        }
    }
    
    /// Convert to string representation
    pub fn as_str(&self) -> String {
        match self {
            KeyCode::Letter(c) => c.to_string(),
            KeyCode::Number(n) => n.to_string(),
            KeyCode::Function(n) => format!("F{}", n),
            
            KeyCode::Control => "Control".to_string(),
            KeyCode::Alt => "Alt".to_string(),
            KeyCode::Shift => "Shift".to_string(),
            KeyCode::Meta => "Meta".to_string(),
            
            KeyCode::Enter => "Enter".to_string(),
            KeyCode::Backspace => "Backspace".to_string(),
            KeyCode::Tab => "Tab".to_string(),
            KeyCode::Escape => "Escape".to_string(),
            KeyCode::Space => "Space".to_string(),
            
            KeyCode::ArrowUp => "ArrowUp".to_string(),
            KeyCode::ArrowDown => "ArrowDown".to_string(),
            KeyCode::ArrowLeft => "ArrowLeft".to_string(),
            KeyCode::ArrowRight => "ArrowRight".to_string(),
            
            KeyCode::Delete => "Delete".to_string(),
            KeyCode::Insert => "Insert".to_string(),
            KeyCode::Home => "Home".to_string(),
            KeyCode::End => "End".to_string(),
            KeyCode::PageUp => "PageUp".to_string(),
            KeyCode::PageDown => "PageDown".to_string(),
            
            KeyCode::Plus => "Plus".to_string(),
            KeyCode::Minus => "Minus".to_string(),
            KeyCode::Equal => "Equal".to_string(),
            KeyCode::BracketLeft => "BracketLeft".to_string(),
            KeyCode::BracketRight => "BracketRight".to_string(),
            KeyCode::Semicolon => "Semicolon".to_string(),
            KeyCode::Quote => "Quote".to_string(),
            KeyCode::Backquote => "Backquote".to_string(),
            KeyCode::Backslash => "Backslash".to_string(),
            KeyCode::Comma => "Comma".to_string(),
            KeyCode::Period => "Period".to_string(),
            KeyCode::Slash => "Slash".to_string(),
            
            KeyCode::Numpad0 => "Numpad0".to_string(),
            KeyCode::Numpad1 => "Numpad1".to_string(),
            KeyCode::Numpad2 => "Numpad2".to_string(),
            KeyCode::Numpad3 => "Numpad3".to_string(),
            KeyCode::Numpad4 => "Numpad4".to_string(),
            KeyCode::Numpad5 => "Numpad5".to_string(),
            KeyCode::Numpad6 => "Numpad6".to_string(),
            KeyCode::Numpad7 => "Numpad7".to_string(),
            KeyCode::Numpad8 => "Numpad8".to_string(),
            KeyCode::Numpad9 => "Numpad9".to_string(),
            KeyCode::NumpadAdd => "NumpadAdd".to_string(),
            KeyCode::NumpadSubtract => "NumpadSubtract".to_string(),
            KeyCode::NumpadMultiply => "NumpadMultiply".to_string(),
            KeyCode::NumpadDivide => "NumpadDivide".to_string(),
            KeyCode::NumpadDecimal => "NumpadDecimal".to_string(),
            KeyCode::NumpadEnter => "NumpadEnter".to_string(),
            
            KeyCode::CapsLock => "CapsLock".to_string(),
            KeyCode::ScrollLock => "ScrollLock".to_string(),
            KeyCode::NumLock => "NumLock".to_string(),
            KeyCode::PrintScreen => "PrintScreen".to_string(),
            KeyCode::Pause => "Pause".to_string(),
            
            KeyCode::MediaPlayPause => "MediaPlayPause".to_string(),
            KeyCode::MediaNext => "MediaNext".to_string(),
            KeyCode::MediaPrev => "MediaPrev".to_string(),
            KeyCode::MediaStop => "MediaStop".to_string(),
            
            KeyCode::Unknown(s) => s.clone(),
        }
    }
    
    /// Check if this is a modifier key
    pub fn is_modifier(&self) -> bool {
        matches!(
            self,
            KeyCode::Control | KeyCode::Alt | KeyCode::Shift | KeyCode::Meta
        )
    }
    
    /// Check if this is a function key
    pub fn is_function(&self) -> bool {
        matches!(self, KeyCode::Function(_))
    }
    
    /// Check if this is an arrow key
    pub fn is_arrow(&self) -> bool {
        matches!(
            self,
            KeyCode::ArrowUp | KeyCode::ArrowDown | KeyCode::ArrowLeft | KeyCode::ArrowRight
        )
    }
}

impl Serialize for KeyCode {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.as_str())
    }
}

impl<'de> Deserialize<'de> for KeyCode {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        Ok(KeyCode::from_str(&s))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_key_code_from_str_letters() {
        assert_eq!(KeyCode::from_str("a"), KeyCode::Letter('A'));
        assert_eq!(KeyCode::from_str("Z"), KeyCode::Letter('Z'));
        assert_eq!(KeyCode::from_str("m"), KeyCode::Letter('M'));
    }
    
    #[test]
    fn test_key_code_from_str_numbers() {
        assert_eq!(KeyCode::from_str("0"), KeyCode::Number(0));
        assert_eq!(KeyCode::from_str("5"), KeyCode::Number(5));
        assert_eq!(KeyCode::from_str("9"), KeyCode::Number(9));
    }
    
    #[test]
    fn test_key_code_from_str_function() {
        assert_eq!(KeyCode::from_str("F1"), KeyCode::Function(1));
        assert_eq!(KeyCode::from_str("f12"), KeyCode::Function(12));
        assert_eq!(KeyCode::from_str("F5"), KeyCode::Function(5));
    }
    
    #[test]
    fn test_key_code_from_str_navigation() {
        assert_eq!(KeyCode::from_str("Enter"), KeyCode::Enter);
        assert_eq!(KeyCode::from_str("backspace"), KeyCode::Backspace);
        assert_eq!(KeyCode::from_str("Tab"), KeyCode::Tab);
        assert_eq!(KeyCode::from_str("ESCAPE"), KeyCode::Escape);
        assert_eq!(KeyCode::from_str("space"), KeyCode::Space);
    }
    
    #[test]
    fn test_key_code_from_str_arrows() {
        assert_eq!(KeyCode::from_str("ArrowUp"), KeyCode::ArrowUp);
        assert_eq!(KeyCode::from_str("arrow_down"), KeyCode::ArrowDown);
        assert_eq!(KeyCode::from_str("left"), KeyCode::ArrowLeft);
        assert_eq!(KeyCode::from_str("RIGHT"), KeyCode::ArrowRight);
    }
    
    #[test]
    fn test_key_code_from_str_modifiers() {
        assert_eq!(KeyCode::from_str("Control"), KeyCode::Control);
        assert_eq!(KeyCode::from_str("alt"), KeyCode::Alt);
        assert_eq!(KeyCode::from_str("SHIFT"), KeyCode::Shift);
        assert_eq!(KeyCode::from_str("windows"), KeyCode::Meta);
        assert_eq!(KeyCode::from_str("command"), KeyCode::Meta);
    }
    
    #[test]
    fn test_key_code_from_str_symbols() {
        assert_eq!(KeyCode::from_str("Plus"), KeyCode::Plus);
        assert_eq!(KeyCode::from_str("minus"), KeyCode::Minus);
        assert_eq!(KeyCode::from_str(";"), KeyCode::Semicolon);
        assert_eq!(KeyCode::from_str("'"), KeyCode::Quote);
        assert_eq!(KeyCode::from_str(","), KeyCode::Comma);
        assert_eq!(KeyCode::from_str("."), KeyCode::Period);
        assert_eq!(KeyCode::from_str("/"), KeyCode::Slash);
    }
    
    #[test]
    fn test_key_code_from_str_unknown() {
        assert_eq!(KeyCode::from_str("invalid_key"), KeyCode::Unknown("invalid_key".to_string()));
        assert_eq!(KeyCode::from_str("F13"), KeyCode::Unknown("f13".to_string()));
    }
    
    #[test]
    fn test_key_code_as_str() {
        assert_eq!(KeyCode::Letter('A').as_str(), "A");
        assert_eq!(KeyCode::Number(5).as_str(), "5");
        assert_eq!(KeyCode::Function(1).as_str(), "F1");
        assert_eq!(KeyCode::Enter.as_str(), "Enter");
        assert_eq!(KeyCode::ArrowUp.as_str(), "ArrowUp");
    }
    
    #[test]
    fn test_key_code_is_modifier() {
        assert!(KeyCode::Control.is_modifier());
        assert!(KeyCode::Alt.is_modifier());
        assert!(KeyCode::Shift.is_modifier());
        assert!(KeyCode::Meta.is_modifier());
        assert!(!KeyCode::Enter.is_modifier());
        assert!(!KeyCode::Letter('A').is_modifier());
    }
    
    #[test]
    fn test_key_code_is_function() {
        assert!(KeyCode::Function(1).is_function());
        assert!(KeyCode::Function(12).is_function());
        assert!(!KeyCode::Enter.is_function());
        assert!(!KeyCode::Letter('A').is_function());
    }
    
    #[test]
    fn test_key_code_is_arrow() {
        assert!(KeyCode::ArrowUp.is_arrow());
        assert!(KeyCode::ArrowDown.is_arrow());
        assert!(KeyCode::ArrowLeft.is_arrow());
        assert!(KeyCode::ArrowRight.is_arrow());
        assert!(!KeyCode::Enter.is_arrow());
    }
    
    #[test]
    fn test_key_code_equality() {
        assert_eq!(KeyCode::Letter('A'), KeyCode::Letter('A'));
        assert_ne!(KeyCode::Letter('A'), KeyCode::Letter('B'));
        assert_eq!(KeyCode::Enter, KeyCode::Enter);
        assert_ne!(KeyCode::Enter, KeyCode::Backspace);
    }
    
    #[test]
    fn test_key_code_serialization() {
        let key = KeyCode::Letter('A');
        let json = serde_json::to_string(&key).unwrap();
        assert_eq!(json, "\"A\"");
        
        let deserialized: KeyCode = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, KeyCode::Letter('A'));
    }
    
    #[test]
    fn test_key_code_deserialization() {
        let json = "\"Enter\"";
        let key: KeyCode = serde_json::from_str(json).unwrap();
        assert_eq!(key, KeyCode::Enter);
    }
}
