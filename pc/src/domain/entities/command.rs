//! Command Entity
//!
//! Commands represent input actions to be executed on the PC.
//! They are the primary domain entity transferred from mobile to PC.

use serde::{Deserialize, Serialize};
use chrono::Utc;
use uuid::Uuid;

use crate::domain::value_objects::*;

/// Unique identifier for a command
pub type CommandId = Uuid;

/// Core Command entity - represents an input action
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "payload")]
pub enum Command {
    /// Mouse-related commands
    #[serde(rename = "mouse")]
    Mouse(MouseCommand),
    
    /// Keyboard-related commands
    #[serde(rename = "keyboard")]
    Keyboard(KeyboardCommand),
    
    /// Media key commands
    #[serde(rename = "media")]
    Media(MediaCommand),
    
    /// Custom/extensible commands
    #[serde(rename = "custom")]
    Custom(CustomCommand),
}

/// Mouse command variants
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "action", content = "data")]
pub enum MouseCommand {
    /// Move mouse relatively (touchpad mode)
    #[serde(rename = "move")]
    Move { 
        /// Horizontal delta in pixels
        dx: i32, 
        /// Vertical delta in pixels  
        dy: i32 
    },
    
    /// Move mouse to absolute position
    #[serde(rename = "move_absolute")]
    MoveAbsolute { 
        /// X coordinate (0 = left edge)
        x: u32, 
        /// Y coordinate (0 = top edge)
        y: u32 
    },
    
    /// Mouse button press or release
    #[serde(rename = "click")]
    Click { 
        /// Which mouse button
        button: MouseButton, 
        /// Press or release
        state: ButtonState 
    },
    
    /// Mouse scroll
    #[serde(rename = "scroll")]
    Scroll { 
        /// Horizontal scroll amount
        dx: i32, 
        /// Vertical scroll amount (positive = down)
        dy: i32 
    },
}

/// Keyboard command variants
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "action", content = "data")]
pub enum KeyboardCommand {
    /// Press a key
    #[serde(rename = "key_press")]
    KeyPress { 
        /// Key code
        key: KeyCode 
    },
    
    /// Release a key
    #[serde(rename = "key_release")]
    KeyRelease { 
        /// Key code
        key: KeyCode 
    },
    
    /// Type a string (optimized for text input)
    #[serde(rename = "type_text")]
    TypeText { 
        /// Text to type
        text: String 
    },
}

/// Media key command variants
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MediaCommand {
    /// Play or pause (toggle)
    #[serde(rename = "play_pause")]
    PlayPause,
    
    /// Next track
    #[serde(rename = "next")]
    NextTrack,
    
    /// Previous track
    #[serde(rename = "prev")]
    PrevTrack,
    
    /// Increase volume
    #[serde(rename = "vol_up")]
    VolumeUp,
    
    /// Decrease volume
    #[serde(rename = "vol_down")]
    VolumeDown,
    
    /// Mute/unmute
    #[serde(rename = "mute")]
    Mute,
}

/// Custom command for extensibility
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CustomCommand {
    /// Action identifier (configured on PC)
    pub id: String,
    /// Action-specific payload
    pub payload: serde_json::Value,
}

impl MouseCommand {
    /// Create a relative mouse move command
    pub fn move_relative(dx: i32, dy: i32) -> Self {
        MouseCommand::Move { dx, dy }
    }
    
    /// Create an absolute mouse move command
    pub fn move_absolute(x: u32, y: u32) -> Self {
        MouseCommand::MoveAbsolute { x, y }
    }
    
    /// Create a mouse click (press + release)
    pub fn click(button: MouseButton) -> Self {
        MouseCommand::Click { 
            button, 
            state: ButtonState::Press 
        }
    }
    
    /// Create a mouse release
    pub fn release(button: MouseButton) -> Self {
        MouseCommand::Click { 
            button, 
            state: ButtonState::Release 
        }
    }
    
    /// Create a scroll command
    pub fn scroll(dx: i32, dy: i32) -> Self {
        MouseCommand::Scroll { dx, dy }
    }
    
    /// Get the mouse action type
    pub fn action_name(&self) -> &'static str {
        match self {
            MouseCommand::Move { .. } => "move",
            MouseCommand::MoveAbsolute { .. } => "move_absolute",
            MouseCommand::Click { .. } => "click",
            MouseCommand::Scroll { .. } => "scroll",
        }
    }
}

impl KeyboardCommand {
    /// Create a key press command
    pub fn press(key: KeyCode) -> Self {
        KeyboardCommand::KeyPress { key }
    }
    
    /// Create a key release command
    pub fn release(key: KeyCode) -> Self {
        KeyboardCommand::KeyRelease { key }
    }
    
    /// Create a text typing command
    pub fn text(text: impl Into<String>) -> Self {
        KeyboardCommand::TypeText { text: text.into() }
    }
    
    /// Get the keyboard action type
    pub fn action_name(&self) -> &'static str {
        match self {
            KeyboardCommand::KeyPress { .. } => "key_press",
            KeyboardCommand::KeyRelease { .. } => "key_release",
            KeyboardCommand::TypeText { .. } => "type_text",
        }
    }
}

impl MediaCommand {
    /// Get the media action type
    pub fn action_name(&self) -> &'static str {
        match self {
            MediaCommand::PlayPause => "play_pause",
            MediaCommand::NextTrack => "next",
            MediaCommand::PrevTrack => "prev",
            MediaCommand::VolumeUp => "vol_up",
            MediaCommand::VolumeDown => "vol_down",
            MediaCommand::Mute => "mute",
        }
    }
}

impl CustomCommand {
    /// Create a new custom command
    pub fn new(id: impl Into<String>, payload: serde_json::Value) -> Self {
        CustomCommand { 
            id: id.into(), 
            payload 
        }
    }
}

/// Wrapper for protocol messages with metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProtocolMessage {
    /// Message type
    #[serde(rename = "type")]
    pub message_type: MessageType,
    
    /// Message payload
    pub payload: serde_json::Value,
    
    /// Timestamp in milliseconds since epoch
    pub timestamp: i64,
    
    /// Optional message ID for correlation
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
}

/// Protocol message types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum MessageType {
    // Connection messages
    ConnectionAccepted,
    ConnectionRejected,
    
    // Command messages
    Mouse,
    Keyboard,
    Media,
    Custom,
    Batch,
    
    // Control messages
    Heartbeat,
    HeartbeatAck,
    Ping,
    Pong,
    
    // Error
    Error,
}

impl ProtocolMessage {
    /// Create a new protocol message
    pub fn new(
        message_type: MessageType,
        payload: serde_json::Value,
        timestamp: i64,
    ) -> Self {
        ProtocolMessage {
            message_type,
            payload,
            timestamp,
            id: None,
        }
    }
    
    /// Set the message ID
    pub fn with_id(mut self, id: impl Into<String>) -> Self {
        self.id = Some(id.into());
        self
    }
    
    /// Get current timestamp in milliseconds
    pub fn now_timestamp() -> i64 {
        Utc::now().timestamp_millis()
    }
    
    /// Create a command message from a Command
    pub fn from_command(command: Command) -> Self {
        let (message_type, payload) = match command {
            Command::Mouse(cmd) => {
                (MessageType::Mouse, serde_json::to_value(cmd).unwrap())
            }
            Command::Keyboard(cmd) => {
                (MessageType::Keyboard, serde_json::to_value(cmd).unwrap())
            }
            Command::Media(cmd) => {
                (MessageType::Media, serde_json::to_value(cmd).unwrap())
            }
            Command::Custom(cmd) => {
                (MessageType::Custom, serde_json::to_value(cmd).unwrap())
            }
        };
        
        ProtocolMessage {
            message_type,
            payload,
            timestamp: Self::now_timestamp(),
            id: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_mouse_command_move_relative() {
        let cmd = MouseCommand::move_relative(10, -5);
        
        match cmd {
            MouseCommand::Move { dx, dy } => {
                assert_eq!(dx, 10);
                assert_eq!(dy, -5);
            }
            _ => panic!("Expected Move variant"),
        }
    }
    
    #[test]
    fn test_mouse_command_click() {
        let cmd = MouseCommand::click(MouseButton::Left);
        
        match cmd {
            MouseCommand::Click { button, state } => {
                assert_eq!(button, MouseButton::Left);
                assert_eq!(state, ButtonState::Press);
            }
            _ => panic!("Expected Click variant"),
        }
    }
    
    #[test]
    fn test_keyboard_command_press() {
        let cmd = KeyboardCommand::press(KeyCode::Letter('A'));
        
        match cmd {
            KeyboardCommand::KeyPress { key } => {
                assert_eq!(key, KeyCode::Letter('A'));
            }
            _ => panic!("Expected KeyPress variant"),
        }
    }
    
    #[test]
    fn test_keyboard_command_text() {
        let cmd = KeyboardCommand::text("Hello");
        
        match cmd {
            KeyboardCommand::TypeText { text } => {
                assert_eq!(text, "Hello");
            }
            _ => panic!("Expected TypeText variant"),
        }
    }
    
    #[test]
    fn test_media_command_play_pause() {
        let cmd = MediaCommand::PlayPause;
        assert_eq!(cmd.action_name(), "play_pause");
    }
    
    #[test]
    fn test_media_command_volume() {
        let cmd = MediaCommand::VolumeUp;
        assert_eq!(cmd.action_name(), "vol_up");
    }
    
    #[test]
    fn test_custom_command() {
        let cmd = CustomCommand::new(
            "launch_youtube",
            serde_json::json!({ "url": "https://youtube.com" })
        );
        
        assert_eq!(cmd.id, "launch_youtube");
        assert_eq!(cmd.payload["url"], "https://youtube.com");
    }
    
    #[test]
    fn test_command_serialization_mouse() {
        let cmd = Command::Mouse(MouseCommand::move_relative(10, -5));
        let json = serde_json::to_value(&cmd).unwrap();
        
        assert_eq!(json["type"], "mouse");
        assert_eq!(json["payload"]["action"], "move");
        assert_eq!(json["payload"]["data"]["dx"], 10);
        assert_eq!(json["payload"]["data"]["dy"], -5);
    }
    
    #[test]
    fn test_command_serialization_keyboard() {
        let cmd = Command::Keyboard(KeyboardCommand::text("Hello"));
        let json = serde_json::to_value(&cmd).unwrap();
        
        assert_eq!(json["type"], "keyboard");
        assert_eq!(json["payload"]["action"], "type_text");
        assert_eq!(json["payload"]["data"]["text"], "Hello");
    }
    
    #[test]
    fn test_command_serialization_media() {
        let cmd = Command::Media(MediaCommand::PlayPause);
        let json = serde_json::to_value(&cmd).unwrap();
        
        assert_eq!(json["type"], "media");
        assert_eq!(json["payload"], "play_pause");
    }
    
    #[test]
    fn test_protocol_message_creation() {
        let cmd = Command::Mouse(MouseCommand::move_relative(5, 3));
        let msg = ProtocolMessage::from_command(cmd.clone());
        
        assert_eq!(msg.message_type, MessageType::Mouse);
        assert!(msg.timestamp > 0);
        assert!(msg.id.is_none());
    }
    
    #[test]
    fn test_protocol_message_with_id() {
        let msg = ProtocolMessage::new(
            MessageType::Heartbeat,
            serde_json::json!({}),
            1234567890,
        ).with_id("test-123");
        
        assert_eq!(msg.id, Some("test-123".to_string()));
    }
    
    #[test]
    fn test_mouse_command_action_names() {
        assert_eq!(MouseCommand::move_relative(0, 0).action_name(), "move");
        assert_eq!(MouseCommand::move_absolute(100, 100).action_name(), "move_absolute");
        assert_eq!(MouseCommand::click(MouseButton::Left).action_name(), "click");
        assert_eq!(MouseCommand::scroll(0, 120).action_name(), "scroll");
    }
    
    #[test]
    fn test_keyboard_command_action_names() {
        assert_eq!(KeyboardCommand::press(KeyCode::Enter).action_name(), "key_press");
        assert_eq!(KeyboardCommand::release(KeyCode::Enter).action_name(), "key_release");
        assert_eq!(KeyboardCommand::text("test").action_name(), "type_text");
    }
    
    #[test]
    fn test_media_command_action_names() {
        assert_eq!(MediaCommand::PlayPause.action_name(), "play_pause");
        assert_eq!(MediaCommand::NextTrack.action_name(), "next");
        assert_eq!(MediaCommand::PrevTrack.action_name(), "prev");
        assert_eq!(MediaCommand::VolumeUp.action_name(), "vol_up");
        assert_eq!(MediaCommand::VolumeDown.action_name(), "vol_down");
        assert_eq!(MediaCommand::Mute.action_name(), "mute");
    }
}
