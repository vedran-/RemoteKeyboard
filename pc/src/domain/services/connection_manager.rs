//! Connection Manager Port
//!
//! Trait for managing connections from mobile devices.

use crate::domain::entities::{Device, Connection};
use crate::domain::value_objects::SessionId;
use crate::application::ports::Result;

/// Trait for managing device connections
#[async_trait::async_trait]
pub trait ConnectionManager: Send + Sync {
    /// Accept a connection from a device
    async fn accept_connection(&self, device: Device) -> Result<Connection>;
    
    /// Reject a connection attempt
    async fn reject_connection(&self, device: &Device, reason: String) -> Result<()>;
    
    /// Disconnect a session
    async fn disconnect_session(&self, session_id: SessionId) -> Result<()>;
    
    /// Disconnect all sessions
    async fn disconnect_all(&self) -> Result<()>;
    
    /// Get active sessions
    fn get_active_sessions(&self) -> Vec<Connection>;
    
    /// Get connection by session ID
    fn get_connection(&self, session_id: SessionId) -> Option<Connection>;
    
    /// Check if there's an active connection
    fn has_active_connection(&self) -> bool;
    
    /// Get connection count
    fn connection_count(&self) -> usize;
}
