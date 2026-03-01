//! Integration and End-to-End Tests
//!
//! This module contains integration tests that test multiple layers together.

// pub mod integration;  // Temporarily disabled due to compilation errors
pub mod mouse_clamping;
pub mod screen_capture;

// pub use integration::*;
pub use mouse_clamping::*;
pub use screen_capture::*;
