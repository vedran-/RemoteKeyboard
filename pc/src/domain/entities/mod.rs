//! Domain Entities
//!
//! Entities are objects with a distinct identity that persist through state changes.

pub mod command;
pub mod device;
pub mod connection;

pub use command::{InputAction, ClientMessage, ServerMessage, MouseCommand, KeyboardCommand, MediaCommand};
pub use device::Device;
pub use connection::Connection;
