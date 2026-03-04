//! Input Executor Port
//!
//! Trait for executing input commands on the PC.
//! This is implemented by infrastructure (enigo adapter).

use crate::domain::entities::command::{MouseCommand, KeyboardCommand, MediaCommand};
use crate::application::ports::Result;

/// Trait for executing input commands on the PC
#[async_trait::async_trait]
pub trait InputExecutor: Send + Sync {
    /// Execute a mouse command
    async fn execute_mouse(&self, command: &MouseCommand) -> Result<()>;
    
    /// Execute a keyboard command
    async fn execute_keyboard(&self, command: &KeyboardCommand) -> Result<()>;
    
    /// Execute a media command
    async fn execute_media(&self, command: &MediaCommand) -> Result<()>;
    
    /// Execute a command based on type
    async fn execute(&self, command: &crate::domain::entities::command::InputAction) -> Result<()> {
        match command {
            crate::domain::entities::command::InputAction::Mouse(cmd) => self.execute_mouse(cmd).await,
            crate::domain::entities::command::InputAction::Keyboard(cmd) => self.execute_keyboard(cmd).await,
            crate::domain::entities::command::InputAction::Media(cmd) => self.execute_media(cmd).await,
        }
    }
}
