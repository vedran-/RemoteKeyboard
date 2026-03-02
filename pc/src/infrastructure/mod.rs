//! Infrastructure Layer
//!
//! The infrastructure layer contains adapters for external concerns:
//! - WebSocket communication
//! - mDNS discovery
//! - Input simulation (enigo)
//! - Connection management
//! - Configuration
//! - Firewall management
//! - Screen capture with cursor (for streaming to mobile)

pub mod websocket;
pub mod mdns;
pub mod input;
pub mod connection;
pub mod config;
pub mod firewall;
pub mod screen_capture;
pub mod screen_capture_utils;
