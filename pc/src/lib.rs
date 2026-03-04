//! RemoteKeyboard PC Application
//!
//! A two-sided application that allows controlling your PC from a mobile device
//! using a virtual touchpad, keyboard, and media keys.
//!
//! # Architecture
//!
//! This application follows Domain-Driven Design (DDD) with layered architecture:
//!
//! - **Domain Layer**: Core business logic, entities, value objects, domain services
//! - **Application Layer**: Use cases, ports (interfaces)
//! - **Infrastructure Layer**: Adapters (WebSocket, mDNS, input simulation)
//! - **Presentation Layer**: Tauri UI, system tray, CLI
//!
//! # Example
//!
//! ```rust
//! use remote_keyboard_pc::domain::entities::command::Command;
//! use remote_keyboard_pc::domain::entities::command::MouseCommand;
//!
//! let cmd = Command::Mouse(MouseCommand::move_relative(10, -5));
//! ```

pub mod domain;
pub mod application;
pub mod infrastructure;
pub mod presentation;

#[cfg(test)]
mod tests;

pub use domain::entities::command::{InputAction, ClientMessage, ServerMessage, MouseCommand, KeyboardCommand, MediaCommand};
pub use domain::value_objects::*;
