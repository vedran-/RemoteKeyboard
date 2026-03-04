//! Command Entity
//!
//! `ClientMessage` — flat JSON messages received from the mobile client.
//! `ServerMessage` — JSON messages sent to the mobile client.
//!
//! Internal domain types (MouseCommand, KeyboardCommand, MediaCommand)
//! remain for the input execution layer (enigo_adapter).

use serde::{Deserialize, Serialize};

use crate::domain::value_objects::*;

// ─────────────────────────────────────────────────────────────────────────────
// Wire protocol – Client → Server
// ─────────────────────────────────────────────────────────────────────────────

/// Flat messages received from the mobile client (JSON text WebSocket frames).
///
/// All variants are tagged with `"type"` at the top level — no nested
/// `payload` wrapper.  Example:
/// ```json
/// { "type": "mouse-move", "dx": 10, "dy": -5 }
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type")]
pub enum ClientMessage {
    #[serde(rename = "mouse-move")]
    MouseMove { dx: i32, dy: i32 },

    #[serde(rename = "mouse-click")]
    MouseClick { button: String, state: String },

    #[serde(rename = "mouse-scroll")]
    MouseScroll { dx: i32, dy: i32 },

    #[serde(rename = "key-press")]
    KeyPress { key: String },

    #[serde(rename = "type-text")]
    TypeText { text: String },

    #[serde(rename = "media-key")]
    MediaKey { key: String },

    /// Start or resume screen streaming at the specified viewport size.
    #[serde(rename = "stream-start")]
    StreamStart { width: u32, height: u32, zoom: f32 },

    /// Update viewport/zoom while already streaming.
    #[serde(rename = "stream-update")]
    StreamUpdate { width: u32, height: u32, zoom: f32 },

    /// Stop screen streaming.
    #[serde(rename = "stream-stop")]
    StreamStop,
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire protocol – Server → Client
// ─────────────────────────────────────────────────────────────────────────────

/// Messages sent from the server to the mobile client (JSON text frames).
/// Screen frames are sent as raw binary WebSocket frames — NOT wrapped here.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    /// Sent immediately after WebSocket handshake completes.
    #[serde(rename = "connected")]
    Connected { session: String },

    /// Sent when the server cannot process a client message.
    #[serde(rename = "error")]
    Error { code: String, message: String },
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal domain types — used by enigo_adapter, NOT serialized on the wire.
// ─────────────────────────────────────────────────────────────────────────────

/// Mouse command — internal representation after parsing from ClientMessage.
#[derive(Debug, Clone, PartialEq)]
pub enum MouseCommand {
    Move { dx: i32, dy: i32 },
    MoveAbsolute { x: u32, y: u32 },
    Click { button: MouseButton, state: ButtonState },
    Scroll { dx: i32, dy: i32 },
}

/// Keyboard command — internal representation.
#[derive(Debug, Clone, PartialEq)]
pub enum KeyboardCommand {
    KeyPress { key: KeyCode },
    KeyRelease { key: KeyCode },
    TypeText { text: String },
}

/// Media command — internal representation.
#[derive(Debug, Clone, PartialEq)]
pub enum MediaCommand {
    PlayPause,
    NextTrack,
    PrevTrack,
    VolumeUp,
    VolumeDown,
    Mute,
}

impl MediaCommand {
    pub fn from_key_str(key: &str) -> Option<Self> {
        match key {
            "play_pause" => Some(MediaCommand::PlayPause),
            "next"       => Some(MediaCommand::NextTrack),
            "prev"       => Some(MediaCommand::PrevTrack),
            "vol_up"     => Some(MediaCommand::VolumeUp),
            "vol_down"   => Some(MediaCommand::VolumeDown),
            "mute"       => Some(MediaCommand::Mute),
            _            => None,
        }
    }
}

/// Convert a `ClientMessage` into the internal mouse/keyboard/media/etc. domain
/// types that the input executor understands.  Returns `Err` for non-input
/// messages (streaming control, etc.) which are handled separately.
#[derive(Debug, Clone)]
pub enum InputAction {
    Mouse(MouseCommand),
    Keyboard(KeyboardCommand),
    Media(MediaCommand),
}

impl ClientMessage {
    /// Try to convert this message into an executable input action.
    pub fn to_input_action(&self) -> Option<InputAction> {
        match self {
            ClientMessage::MouseMove { dx, dy } =>
                Some(InputAction::Mouse(MouseCommand::Move { dx: *dx, dy: *dy })),

            ClientMessage::MouseClick { button, state } => {
                let btn = MouseButton::from_str(button)?;
                let st = ButtonState::from_str(state)?;
                Some(InputAction::Mouse(MouseCommand::Click { button: btn, state: st }))
            }

            ClientMessage::MouseScroll { dx, dy } =>
                Some(InputAction::Mouse(MouseCommand::Scroll { dx: *dx, dy: *dy })),

            ClientMessage::KeyPress { key } => {
                let kc = KeyCode::from_str(key);
                Some(InputAction::Keyboard(KeyboardCommand::KeyPress { key: kc }))
            }

            ClientMessage::TypeText { text } =>
                Some(InputAction::Keyboard(KeyboardCommand::TypeText { text: text.clone() })),

            ClientMessage::MediaKey { key } =>
                MediaCommand::from_key_str(key).map(InputAction::Media),

            // Streaming control messages — handled at server level, not here.
            ClientMessage::StreamStart { .. }
            | ClientMessage::StreamUpdate { .. }
            | ClientMessage::StreamStop => None,
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── Deserialization of client messages ───────────────────────────────────

    #[test]
    fn test_parse_mouse_move() {
        let json = r#"{"type":"mouse-move","dx":10,"dy":-5}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::MouseMove { dx: 10, dy: -5 });
    }

    #[test]
    fn test_parse_mouse_click() {
        let json = r#"{"type":"mouse-click","button":"left","state":"press"}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::MouseClick { button: "left".into(), state: "press".into() });
    }

    #[test]
    fn test_parse_mouse_scroll() {
        let json = r#"{"type":"mouse-scroll","dx":0,"dy":120}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::MouseScroll { dx: 0, dy: 120 });
    }

    #[test]
    fn test_parse_key_press() {
        let json = r#"{"type":"key-press","key":"A"}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::KeyPress { key: "A".into() });
    }

    #[test]
    fn test_parse_type_text() {
        let json = r#"{"type":"type-text","text":"Hello World"}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::TypeText { text: "Hello World".into() });
    }

    #[test]
    fn test_parse_media_key() {
        let json = r#"{"type":"media-key","key":"play_pause"}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::MediaKey { key: "play_pause".into() });
    }

    #[test]
    fn test_parse_stream_start() {
        let json = r#"{"type":"stream-start","width":800,"height":600,"zoom":1.5}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::StreamStart { width: 800, height: 600, zoom: 1.5 });
    }

    #[test]
    fn test_parse_stream_update() {
        let json = r#"{"type":"stream-update","width":800,"height":600,"zoom":2.0}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::StreamUpdate { width: 800, height: 600, zoom: 2.0 });
    }

    #[test]
    fn test_parse_stream_stop() {
        let json = r#"{"type":"stream-stop"}"#;
        let msg: ClientMessage = serde_json::from_str(json).unwrap();
        assert_eq!(msg, ClientMessage::StreamStop);
    }

    #[test]
    fn test_parse_unknown_type_fails() {
        let json = r#"{"type":"unknown-thing","foo":"bar"}"#;
        let result: Result<ClientMessage, _> = serde_json::from_str(json);
        assert!(result.is_err());
    }

    // ── Serialization of server messages ────────────────────────────────────

    #[test]
    fn test_serialize_connected() {
        let msg = ServerMessage::Connected { session: "abc-123".into() };
        let json = serde_json::to_value(&msg).unwrap();
        assert_eq!(json["type"], "connected");
        assert_eq!(json["session"], "abc-123");
    }

    #[test]
    fn test_serialize_error() {
        let msg = ServerMessage::Error {
            code: "invalid_message".into(),
            message: "Unknown command".into(),
        };
        let json = serde_json::to_value(&msg).unwrap();
        assert_eq!(json["type"], "error");
        assert_eq!(json["code"], "invalid_message");
    }

    // ── to_input_action ──────────────────────────────────────────────────────

    #[test]
    fn test_mouse_move_to_action() {
        let msg = ClientMessage::MouseMove { dx: 5, dy: -3 };
        match msg.to_input_action().unwrap() {
            InputAction::Mouse(MouseCommand::Move { dx, dy }) => {
                assert_eq!(dx, 5);
                assert_eq!(dy, -3);
            }
            _ => panic!("Expected Mouse::Move"),
        }
    }

    #[test]
    fn test_mouse_click_to_action() {
        let msg = ClientMessage::MouseClick { button: "right".into(), state: "release".into() };
        match msg.to_input_action().unwrap() {
            InputAction::Mouse(MouseCommand::Click { button, state }) => {
                assert_eq!(button, MouseButton::Right);
                assert_eq!(state, ButtonState::Release);
            }
            _ => panic!("Expected Mouse::Click"),
        }
    }

    #[test]
    fn test_media_key_to_action() {
        let msg = ClientMessage::MediaKey { key: "next".into() };
        match msg.to_input_action().unwrap() {
            InputAction::Media(MediaCommand::NextTrack) => {}
            _ => panic!("Expected Media::NextTrack"),
        }
    }

    #[test]
    fn test_stream_stop_has_no_action() {
        let msg = ClientMessage::StreamStop;
        assert!(msg.to_input_action().is_none());
    }
}
