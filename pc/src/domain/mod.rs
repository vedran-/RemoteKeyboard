//! Domain Layer - Core business logic
//!
//! This layer contains the heart of the application:
//! - **Entities**: Objects with identity (Command, Device, Connection)
//! - **Value Objects**: Immutable objects defined by their attributes (MouseButton, KeyCode)
//! - **Domain Services**: Business logic interfaces (InputExecutor, CommandHandler)
//!
//! The domain layer has NO dependencies on external libraries (frameworks, databases, etc.)
//! and contains no I/O code.

pub mod entities;
pub mod value_objects;
pub mod services;
