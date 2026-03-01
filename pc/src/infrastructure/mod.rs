//! Infrastructure Layer
//!
//! The infrastructure layer contains adapters for external concerns:
//! - WebSocket communication
//! - mDNS discovery
//! - Input simulation (enigo)
//! - Connection management
//! - Configuration
//! - Firewall management
//! - Screen capture (for streaming to mobile)
//! - Cursor position (cross-platform physical coordinates)

pub mod cursor;
pub mod websocket;
pub mod mdns;
pub mod input;
pub mod connection;
pub mod config;
pub mod firewall;
pub mod screen_capture;
