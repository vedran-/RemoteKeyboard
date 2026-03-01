//! Connection Entity
//!
//! Represents an active connection between a mobile device and the PC.

use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

use crate::domain::value_objects::SessionId;
use crate::domain::entities::Device;

/// Unique identifier for a connection
pub type ConnectionId = Uuid;

/// Represents an active connection with a mobile device
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Connection {
    /// Unique connection identifier
    pub id: ConnectionId,
    
    /// Session identifier
    pub session_id: SessionId,
    
    /// Connected device
    pub device: Device,
    
    /// When the connection was established
    pub established_at: DateTime<Utc>,
    
    /// Last activity timestamp
    pub last_activity: DateTime<Utc>,
    
    /// Whether the connection is active
    pub is_active: bool,
}

impl Connection {
    /// Create a new connection from a device
    pub fn new(device: Device) -> Self {
        let now = Utc::now();
        Connection {
            id: ConnectionId::new_v4(),
            session_id: SessionId::new(),
            device,
            established_at: now,
            last_activity: now,
            is_active: true,
        }
    }
    
    /// Update last activity timestamp
    pub fn touch(&mut self) {
        self.last_activity = Utc::now();
    }
    
    /// Mark connection as inactive
    pub fn deactivate(&mut self) {
        self.is_active = false;
    }
    
    /// Check if connection is active
    pub fn is_active(&self) -> bool {
        self.is_active
    }
    
    /// Get connection duration in seconds
    pub fn duration_secs(&self) -> i64 {
        Utc::now()
            .signed_duration_since(self.established_at)
            .num_seconds()
    }
    
    /// Get idle time in seconds (since last activity)
    pub fn idle_secs(&self) -> i64 {
        Utc::now()
            .signed_duration_since(self.last_activity)
            .num_seconds()
    }
    
    /// Check if connection is stale (no activity for given seconds)
    pub fn is_stale(&self, threshold_secs: i64) -> bool {
        self.idle_secs() > threshold_secs
    }
}

impl std::fmt::Display for Connection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Connection[{}: {}] (session: {}, active: {}, duration: {}s)",
            self.id,
            self.device.name,
            self.session_id.as_uuid(),
            self.is_active,
            self.duration_secs()
        )
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
    
    fn create_test_connection() -> Connection {
        Connection::new(create_test_device())
    }
    
    #[test]
    fn test_connection_new() {
        let device = create_test_device();
        let conn = Connection::new(device.clone());
        
        assert!(conn.id.as_hyphenated().to_string().len() > 0);
        assert_eq!(conn.device, device);
        assert!(conn.is_active);
        assert!(conn.established_at <= Utc::now());
        assert!(conn.last_activity <= Utc::now());
    }
    
    #[test]
    fn test_connection_session_id() {
        let conn = create_test_connection();
        assert!(conn.session_id.as_uuid().as_hyphenated().to_string().len() > 0);
    }
    
    #[test]
    fn test_connection_touch() {
        let mut conn = create_test_connection();
        let before = conn.last_activity;
        
        std::thread::sleep(std::time::Duration::from_millis(10));
        conn.touch();
        
        assert!(conn.last_activity >= before);
    }
    
    #[test]
    fn test_connection_deactivate() {
        let mut conn = create_test_connection();
        assert!(conn.is_active());
        
        conn.deactivate();
        assert!(!conn.is_active());
    }
    
    #[test]
    fn test_connection_duration() {
        let conn = create_test_connection();
        
        // Duration should be very small (just created)
        let duration = conn.duration_secs();
        assert!(duration >= 0);
        assert!(duration < 60); // Should be less than a minute
    }
    
    #[test]
    fn test_connection_idle() {
        let conn = create_test_connection();
        
        // Idle should be very small (just created)
        let idle = conn.idle_secs();
        assert!(idle >= 0);
        assert!(idle < 60);
    }
    
    #[test]
    fn test_connection_is_stale() {
        let mut conn = create_test_connection();
        
        // Should not be stale with 30 second threshold
        assert!(!conn.is_stale(30));
        
        // Manually set last_activity to 2 minutes ago
        conn.last_activity = Utc::now() - chrono::Duration::minutes(2);
        
        // Should be stale with 30 second threshold
        assert!(conn.is_stale(30));
        
        // Should not be stale with 5 minute threshold
        assert!(!conn.is_stale(300));
    }
    
    #[test]
    fn test_connection_display() {
        let conn = create_test_connection();
        let display = format!("{}", conn);
        
        assert!(display.contains("Connection["));
        assert!(display.contains("TestPhone"));
        assert!(display.contains("session:"));
        assert!(display.contains("active: true"));
    }
    
    #[test]
    fn test_connection_equality() {
        let conn1 = create_test_connection();
        let mut conn2 = conn1.clone();
        
        assert_eq!(conn1, conn2);
        
        conn2.deactivate();
        assert_ne!(conn1, conn2);
    }
    
    #[test]
    fn test_connection_serialization() {
        let conn = create_test_connection();
        let json = serde_json::to_string_pretty(&conn).unwrap();
        
        // Should contain key fields
        assert!(json.contains("TestPhone"));
        assert!(json.contains("is_active"));
        assert!(json.contains("established_at"));
        
        // Should deserialize correctly
        let deserialized: Connection = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.id, conn.id);
        assert_eq!(deserialized.device.name, conn.device.name);
    }
}
