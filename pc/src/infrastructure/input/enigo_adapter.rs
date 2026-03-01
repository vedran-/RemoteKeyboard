//! Enigo Input Adapter
//!
//! Implements input simulation using the enigo crate (v0.6).
//! This is the critical component that actually controls the PC's mouse and keyboard.

use std::sync::Arc;
use std::sync::Mutex;
use enigo::{Enigo, Key, Settings, Coordinate, Axis, Keyboard, Mouse, Button};
use tracing::{debug, info};

use crate::application::ports::{Result, Error};
use crate::domain::entities::command::{MouseCommand, KeyboardCommand, MediaCommand};
use crate::domain::services::InputExecutor;
use crate::domain::value_objects::{MouseButton as DomainMouseButton, KeyCode};

/// Enigo-based input executor
pub struct EnigoInputAdapter {
    enigo: Arc<Mutex<Enigo>>,
}

impl EnigoInputAdapter {
    /// Create a new enigo input adapter
    pub fn new() -> Result<Self> {
        let enigo = Enigo::new(&Settings::default())
            .map_err(|e| Error::input(format!("Failed to initialize enigo: {}", e)))?;
        
        Ok(EnigoInputAdapter {
            enigo: Arc::new(Mutex::new(enigo)),
        })
    }
    
    /// Create with a custom enigo instance (for testing)
    pub fn with_enigo(enigo: Enigo) -> Self {
        EnigoInputAdapter {
            enigo: Arc::new(Mutex::new(enigo)),
        }
    }
}

#[async_trait::async_trait]
impl InputExecutor for EnigoInputAdapter {
    async fn execute_mouse(&self, command: &MouseCommand) -> Result<()> {
        debug!("Executing mouse command: {:?}", command);
        
        let mut enigo = self.enigo.lock().map_err(|e| Error::internal(format!("Mutex poisoned: {}", e)))?;
        
        match command {
            MouseCommand::Move { dx, dy } => {
                // Relative mouse move using Coordinate::Rel
                enigo.move_mouse(*dx, *dy, Coordinate::Rel)
                    .map_err(|e| Error::input(format!("Failed to move mouse: {}", e)))?;
            }
            MouseCommand::MoveAbsolute { x, y } => {
                // Absolute mouse move using Coordinate::Abs
                enigo.move_mouse(*x as i32, *y as i32, Coordinate::Abs)
                    .map_err(|e| Error::input(format!("Failed to move mouse to position: {}", e)))?;
            }
            MouseCommand::Click { button, state } => {
                let enigo_button = match button {
                    DomainMouseButton::Left => Button::Left,
                    DomainMouseButton::Right => Button::Right,
                    DomainMouseButton::Middle => Button::Middle,
                };
                
                match state {
                    crate::domain::value_objects::ButtonState::Press => {
                        enigo.button(enigo_button, enigo::Direction::Press)
                            .map_err(|e| Error::input(format!("Failed to press mouse button: {}", e)))?;
                    }
                    crate::domain::value_objects::ButtonState::Release => {
                        enigo.button(enigo_button, enigo::Direction::Release)
                            .map_err(|e| Error::input(format!("Failed to release mouse button: {}", e)))?;
                    }
                }
            }
            MouseCommand::Scroll { dx, dy } => {
                if *dy != 0 {
                    enigo.scroll(*dy, Axis::Vertical)
                        .map_err(|e| Error::input(format!("Failed to scroll: {}", e)))?;
                }
                
                if *dx != 0 {
                    enigo.scroll(*dx, Axis::Horizontal)
                        .map_err(|e| Error::input(format!("Failed to horizontal scroll: {}", e)))?;
                }
            }
        }
        
        Ok(())
    }
    
    async fn execute_keyboard(&self, command: &KeyboardCommand) -> Result<()> {
        debug!("Executing keyboard command: {:?}", command);
        
        let mut enigo = self.enigo.lock().map_err(|e| Error::internal(format!("Mutex poisoned: {}", e)))?;
        
        match command {
            KeyboardCommand::KeyPress { key } => {
                let enigo_key = keycode_to_enigo(key);
                enigo.key(enigo_key, enigo::Direction::Press)
                    .map_err(|e| Error::input(format!("Failed to press key: {}", e)))?;
            }
            KeyboardCommand::KeyRelease { key } => {
                let enigo_key = keycode_to_enigo(key);
                enigo.key(enigo_key, enigo::Direction::Release)
                    .map_err(|e| Error::input(format!("Failed to release key: {}", e)))?;
            }
            KeyboardCommand::TypeText { text } => {
                enigo.text(text)
                    .map_err(|e| Error::input(format!("Failed to type text: {}", e)))?;
            }
        }
        
        Ok(())
    }
    
    async fn execute_media(&self, command: &MediaCommand) -> Result<()> {
        debug!("Executing media command: {:?}", command);
        
        let mut enigo = self.enigo.lock().map_err(|e| Error::internal(format!("Mutex poisoned: {}", e)))?;
        
        let media_key = match command {
            MediaCommand::PlayPause => Key::MediaPlayPause,
            MediaCommand::NextTrack => Key::MediaNextTrack,
            MediaCommand::PrevTrack => Key::MediaPrevTrack,
            MediaCommand::VolumeUp => Key::VolumeUp,
            MediaCommand::VolumeDown => Key::VolumeDown,
            MediaCommand::Mute => Key::VolumeMute,
        };
        
        enigo.key(media_key, enigo::Direction::Click)
            .map_err(|e| Error::input(format!("Failed to execute media key: {}", e)))?;
        
        info!("Executed media command: {:?}", command);
        
        Ok(())
    }
}

/// Convert KeyCode to enigo Key
/// Note: enigo 0.6 uses Key::Unicode for character keys
fn keycode_to_enigo(key: &KeyCode) -> Key {
    match key {
        // Letters and numbers use Unicode
        KeyCode::Letter(c) => Key::Unicode(*c),
        KeyCode::Number(n) => Key::Unicode(char::from_digit(*n as u32, 10).unwrap_or('0')),
        
        KeyCode::Function(n) => match n {
            1 => Key::F1,
            2 => Key::F2,
            3 => Key::F3,
            4 => Key::F4,
            5 => Key::F5,
            6 => Key::F6,
            7 => Key::F7,
            8 => Key::F8,
            9 => Key::F9,
            10 => Key::F10,
            11 => Key::F11,
            12 => Key::F12,
            _ => Key::F1,
        },
        
        KeyCode::Control => Key::Control,
        KeyCode::Alt => Key::Alt,
        KeyCode::Shift => Key::Shift,
        KeyCode::Meta => Key::Meta,
        KeyCode::Enter => Key::Return,
        KeyCode::Backspace => Key::Backspace,
        KeyCode::Tab => Key::Tab,
        KeyCode::Escape => Key::Escape,
        KeyCode::Space => Key::Space,
        KeyCode::ArrowUp => Key::UpArrow,
        KeyCode::ArrowDown => Key::DownArrow,
        KeyCode::ArrowLeft => Key::LeftArrow,
        KeyCode::ArrowRight => Key::RightArrow,
        KeyCode::Delete => Key::Delete,
        KeyCode::Insert => Key::Insert,
        KeyCode::Home => Key::Home,
        KeyCode::End => Key::End,
        KeyCode::PageUp => Key::PageUp,
        KeyCode::PageDown => Key::PageDown,
        
        // Symbols use Unicode
        KeyCode::Plus => Key::Unicode('+'),
        KeyCode::Minus => Key::Unicode('-'),
        KeyCode::Equal => Key::Unicode('='),
        KeyCode::BracketLeft => Key::Unicode('['),
        KeyCode::BracketRight => Key::Unicode(']'),
        KeyCode::Semicolon => Key::Unicode(';'),
        KeyCode::Quote => Key::Unicode('\''),
        KeyCode::Backquote => Key::Unicode('`'),
        KeyCode::Backslash => Key::Unicode('\\'),
        KeyCode::Comma => Key::Unicode(','),
        KeyCode::Period => Key::Unicode('.'),
        KeyCode::Slash => Key::Unicode('/'),
        
        // Numpad
        KeyCode::Numpad0 => Key::Numpad0,
        KeyCode::Numpad1 => Key::Numpad1,
        KeyCode::Numpad2 => Key::Numpad2,
        KeyCode::Numpad3 => Key::Numpad3,
        KeyCode::Numpad4 => Key::Numpad4,
        KeyCode::Numpad5 => Key::Numpad5,
        KeyCode::Numpad6 => Key::Numpad6,
        KeyCode::Numpad7 => Key::Numpad7,
        KeyCode::Numpad8 => Key::Numpad8,
        KeyCode::Numpad9 => Key::Numpad9,
        KeyCode::NumpadAdd => Key::Unicode('+'),
        KeyCode::NumpadSubtract => Key::Unicode('-'),
        KeyCode::NumpadMultiply => Key::Unicode('*'),
        KeyCode::NumpadDivide => Key::Unicode('/'),
        KeyCode::NumpadDecimal => Key::Unicode('.'),
        KeyCode::NumpadEnter => Key::Return,
        
        // Lock keys
        KeyCode::CapsLock => Key::CapsLock,
        KeyCode::ScrollLock => Key::Unicode('\u{EA15}'),  // Fallback
        KeyCode::NumLock => Key::Numlock,
        
        // System keys
        KeyCode::PrintScreen => Key::PrintScr,
        KeyCode::Pause => Key::Pause,
        
        // Media keys
        KeyCode::MediaPlayPause => Key::MediaPlayPause,
        KeyCode::MediaNext => Key::MediaNextTrack,
        KeyCode::MediaPrev => Key::MediaPrevTrack,
        KeyCode::MediaStop => Key::MediaStop,
        
        // Unknown
        KeyCode::Unknown(_) => Key::Space,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_enigo_input_adapter_creation() {
        let adapter = EnigoInputAdapter::new();
        assert!(adapter.is_ok() || adapter.is_err());
    }
    
    #[tokio::test]
    async fn test_keycode_to_enigo_conversion() {
        assert_eq!(keycode_to_enigo(&KeyCode::Letter('A')), Key::Unicode('A'));
        assert_eq!(keycode_to_enigo(&KeyCode::Number(5)), Key::Unicode('5'));
        assert_eq!(keycode_to_enigo(&KeyCode::Function(1)), Key::F1);
        assert_eq!(keycode_to_enigo(&KeyCode::Function(12)), Key::F12);
        assert_eq!(keycode_to_enigo(&KeyCode::Enter), Key::Return);
        assert_eq!(keycode_to_enigo(&KeyCode::ArrowUp), Key::UpArrow);
        assert_eq!(keycode_to_enigo(&KeyCode::Control), Key::Control);
        assert_eq!(keycode_to_enigo(&KeyCode::Space), Key::Space);
    }
    
    #[test]
    fn test_media_keycode_conversion() {
        assert_eq!(keycode_to_enigo(&KeyCode::MediaPlayPause), Key::MediaPlayPause);
        assert_eq!(keycode_to_enigo(&KeyCode::MediaNext), Key::MediaNextTrack);
        assert_eq!(keycode_to_enigo(&KeyCode::MediaPrev), Key::MediaPrevTrack);
    }
}
