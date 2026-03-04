//! Command Handler Port
//!
//! Trait for handling incoming commands from mobile devices.

use crate::domain::entities::command::InputAction;
use crate::application::ports::Result;

/// Trait for handling incoming commands
#[async_trait::async_trait]
pub trait CommandHandler: Send + Sync {
    /// Handle an incoming command
    async fn handle(&self, command: InputAction) -> Result<()>;
}
