//! WebSocket Infrastructure
//!
//! WebSocket server implementation for receiving commands from mobile devices.

pub mod server;

pub use server::{WebSocketServer, WebSocketConfig, IncomingCommand};
