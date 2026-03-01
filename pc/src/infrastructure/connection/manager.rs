//! Connection Manager
//!
//! Manages device connections with single-client model (MVP).
//! New connections disconnect existing clients.

use parking_lot::RwLock;
use tracing::{info, warn};

use crate::application::ports::{Result, Error};
use crate::domain::entities::{Connection, Device};
use crate::domain::services::ConnectionManager;
use crate::domain::value_objects::SessionId;

/// Connection manager configuration
#[derive(Debug, Clone)]
pub struct ConnectionManagerConfig {
    /// Maximum number of concurrent connections (1 for MVP)
    pub max_connections: usize,
    /// Auto-disconnect existing client when new one connects
    pub auto_disconnect: bool,
    /// Session timeout in seconds
    pub session_timeout_secs: u64,
}

impl Default for ConnectionManagerConfig {
    fn default() -> Self {
        ConnectionManagerConfig {
            max_connections: 1,
            auto_disconnect: true,
            session_timeout_secs: 300, // 5 minutes
        }
    }
}

/// In-memory connection manager
pub struct InMemoryConnectionManager {
    connections: RwLock<Vec<Connection>>,
    config: ConnectionManagerConfig,
}

impl InMemoryConnectionManager {
    /// Create a new connection manager
    pub fn new(config: ConnectionManagerConfig) -> Self {
        InMemoryConnectionManager {
            connections: RwLock::new(Vec::new()),
            config,
        }
    }
    
    /// Create with default config
    pub fn with_defaults() -> Self {
        Self::new(ConnectionManagerConfig::default())
    }
    
    /// Clean up stale connections
    pub fn cleanup_stale(&self) -> usize {
        let mut connections = self.connections.write();
        let before = connections.len();
        
        connections.retain(|conn| {
            !conn.is_stale(self.config.session_timeout_secs as i64)
        });
        
        let removed = before - connections.len();
        if removed > 0 {
            info!("Cleaned up {} stale connections", removed);
        }
        removed
    }
}

#[async_trait::async_trait]
impl ConnectionManager for InMemoryConnectionManager {
    async fn accept_connection(&self, device: Device) -> Result<Connection> {
        let mut connections = self.connections.write();
        
        // Check if we're at max capacity
        if connections.len() >= self.config.max_connections {
            if self.config.auto_disconnect {
                // Disconnect existing client
                if let Some(existing) = connections.first() {
                    warn!(
                        "Disconnecting existing client {} to accept new connection from {}",
                        existing.device.name,
                        device.name
                    );
                }
                connections.clear();
            } else {
                return Err(Error::connection(
                    "Server already has maximum number of connections"
                ));
            }
        }
        
        // Create new connection
        let connection = Connection::new(device);
        info!("Accepted new connection: {}", connection);
        
        connections.push(connection.clone());
        
        Ok(connection)
    }
    
    async fn reject_connection(&self, device: &Device, reason: String) -> Result<()> {
        warn!("Rejected connection from {}: {}", device.name, reason);
        Ok(())
    }
    
    async fn disconnect_session(&self, session_id: SessionId) -> Result<()> {
        let mut connections = self.connections.write();
        
        if let Some(pos) = connections.iter().position(|c| c.session_id == session_id) {
            let conn = connections.remove(pos);
            info!("Disconnected session: {}", conn);
        }
        
        Ok(())
    }
    
    async fn disconnect_all(&self) -> Result<()> {
        let mut connections = self.connections.write();
        let count = connections.len();
        connections.clear();
        info!("Disconnected all {} sessions", count);
        Ok(())
    }
    
    fn get_active_sessions(&self) -> Vec<Connection> {
        self.connections.read().clone()
    }
    
    fn get_connection(&self, session_id: SessionId) -> Option<Connection> {
        self.connections
            .read()
            .iter()
            .find(|c| c.session_id == session_id)
            .cloned()
    }
    
    fn has_active_connection(&self) -> bool {
        !self.connections.read().is_empty()
    }
    
    fn connection_count(&self) -> usize {
        self.connections.read().len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    fn create_test_device() -> Device {
        Device::from_discovery(
            "TestPhone".to_string(),
            "192.168.1.100".to_string(),
            8765,
            "/remote".to_string(),
            "1.0".to_string(),
        )
    }
    
    #[tokio::test]
    async fn test_connection_manager_accept() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        assert!(!manager.has_active_connection());
        
        let device = create_test_device();
        let result = manager.accept_connection(device).await;
        
        assert!(result.is_ok());
        assert!(manager.has_active_connection());
        assert_eq!(manager.connection_count(), 1);
    }
    
    #[tokio::test]
    async fn test_connection_manager_auto_disconnect() {
        let mut config = ConnectionManagerConfig::default();
        config.auto_disconnect = true;
        config.max_connections = 1;
        
        let manager = InMemoryConnectionManager::new(config);
        
        // First connection
        let device1 = create_test_device();
        let conn1 = manager.accept_connection(device1).await.unwrap();
        assert_eq!(manager.connection_count(), 1);
        
        // Second connection should disconnect first
        let device2 = Device::from_discovery(
            "TestPhone2".to_string(),
            "192.168.1.101".to_string(),
            8765,
            "/remote".to_string(),
            "1.0".to_string(),
        );
        let conn2 = manager.accept_connection(device2).await.unwrap();
        
        // Should only have second connection
        assert_eq!(manager.connection_count(), 1);
        let sessions = manager.get_active_sessions();
        assert_eq!(sessions[0].device.name, "TestPhone2");
        
        // First session should be different
        assert_ne!(conn1.session_id, conn2.session_id);
    }
    
    #[tokio::test]
    async fn test_connection_manager_reject() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        let device = create_test_device();
        let result = manager.reject_connection(&device, "Testing rejection".to_string()).await;
        
        assert!(result.is_ok());
        assert!(!manager.has_active_connection());
    }
    
    #[tokio::test]
    async fn test_connection_manager_disconnect_session() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        let device = create_test_device();
        let conn = manager.accept_connection(device).await.unwrap();
        let session_id = conn.session_id;
        
        assert!(manager.has_active_connection());
        
        let result = manager.disconnect_session(session_id).await;
        
        assert!(result.is_ok());
        assert!(!manager.has_active_connection());
    }
    
    #[tokio::test]
    async fn test_connection_manager_disconnect_all() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        // Accept multiple connections (we'll manually add them)
        let device1 = create_test_device();
        let device2 = create_test_device();
        
        let _conn1 = manager.accept_connection(device1).await.unwrap();
        let _conn2 = manager.accept_connection(device2).await.unwrap();
        
        // Due to auto_disconnect, should only have 1
        assert_eq!(manager.connection_count(), 1);
        
        let result = manager.disconnect_all().await;
        
        assert!(result.is_ok());
        assert_eq!(manager.connection_count(), 0);
    }
    
    #[tokio::test]
    async fn test_connection_manager_get_connection() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        let device = create_test_device();
        let conn = manager.accept_connection(device).await.unwrap();
        let session_id = conn.session_id;
        
        let retrieved = manager.get_connection(session_id);
        
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().session_id, session_id);
    }
    
    #[tokio::test]
    async fn test_connection_manager_cleanup_stale() {
        let manager = InMemoryConnectionManager::with_defaults();
        
        let device = create_test_device();
        let _conn = manager.accept_connection(device).await.unwrap();
        
        // Should not clean up fresh connection
        let cleaned = manager.cleanup_stale();
        assert_eq!(cleaned, 0);
        assert_eq!(manager.connection_count(), 1);
    }
}
