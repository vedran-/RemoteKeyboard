//! Domain Value Objects
//!
//! Value objects are immutable objects defined by their attributes rather than identity.
//! They implement equality by value and have no side effects.

pub mod mouse;
pub mod keyboard;
pub mod device;

pub use mouse::{MouseButton, ButtonState};
pub use keyboard::KeyCode;
pub use device::{DeviceId, SessionId, DeviceStatus};
