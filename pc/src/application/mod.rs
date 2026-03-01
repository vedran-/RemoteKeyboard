//! Application Layer
//!
//! The application layer contains use cases and ports (interfaces).
//! It orchestrates the domain layer to perform application tasks.

pub mod ports;
pub mod use_cases;

pub use ports::{Result, Error};
