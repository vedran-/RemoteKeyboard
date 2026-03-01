//! Connection Infrastructure
//!
//! Connection management for device sessions.

pub mod manager;

pub use manager::{InMemoryConnectionManager, ConnectionManagerConfig};
