//! Device Value Objects
//!
//! Immutable value objects for device identification and status.

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Unique identifier for a device
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct DeviceId(pub Uuid);

impl DeviceId {
    /// Generate a new random device ID
    pub fn new() -> Self {
        DeviceId(Uuid::new_v4())
    }
    
    /// Parse from a UUID string
    pub fn parse(s: &str) -> Result<Self, uuid::Error> {
        Uuid::parse_str(s).map(DeviceId)
    }
    
    /// Get the UUID value
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl Default for DeviceId {
    fn default() -> Self {
        Self::new()
    }
}

impl Serialize for DeviceId {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.0.to_string())
    }
}

impl<'de> Deserialize<'de> for DeviceId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        DeviceId::parse(&s).map_err(serde::de::Error::custom)
    }
}

/// Unique identifier for a session
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SessionId(pub Uuid);

impl SessionId {
    /// Generate a new random session ID
    pub fn new() -> Self {
        SessionId(Uuid::new_v4())
    }
    
    /// Parse from a UUID string
    pub fn parse(s: &str) -> Result<Self, uuid::Error> {
        Uuid::parse_str(s).map(SessionId)
    }
    
    /// Get the UUID value
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl Default for SessionId {
    fn default() -> Self {
        Self::new()
    }
}

impl Serialize for SessionId {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.0.to_string())
    }
}

impl<'de> Deserialize<'de> for SessionId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        SessionId::parse(&s).map_err(serde::de::Error::custom)
    }
}

/// Device connection status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum DeviceStatus {
    /// Device is available for connection
    #[serde(rename = "available")]
    Available,
    
    /// Device is connecting
    #[serde(rename = "connecting")]
    Connecting,
    
    /// Device is connected
    #[serde(rename = "connected")]
    Connected,
    
    /// Device is unavailable
    #[serde(rename = "unavailable")]
    Unavailable,
}

impl DeviceStatus {
    /// Check if device is available for connection
    pub fn is_available(&self) -> bool {
        matches!(self, DeviceStatus::Available)
    }
    
    /// Check if device is currently connecting
    pub fn is_connecting(&self) -> bool {
        matches!(self, DeviceStatus::Connecting)
    }
    
    /// Check if device is connected
    pub fn is_connected(&self) -> bool {
        matches!(self, DeviceStatus::Connected)
    }
    
    /// Check if device is unavailable
    pub fn is_unavailable(&self) -> bool {
        matches!(self, DeviceStatus::Unavailable)
    }
    
    /// Get status as string
    pub fn as_str(&self) -> &'static str {
        match self {
            DeviceStatus::Available => "available",
            DeviceStatus::Connecting => "connecting",
            DeviceStatus::Connected => "connected",
            DeviceStatus::Unavailable => "unavailable",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_device_id_new() {
        let id1 = DeviceId::new();
        let id2 = DeviceId::new();
        
        // IDs should be unique
        assert_ne!(id1, id2);
    }
    
    #[test]
    fn test_device_id_parse() {
        let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
        let id = DeviceId::parse(uuid_str).unwrap();
        
        assert_eq!(id.as_uuid().to_string(), uuid_str);
    }
    
    #[test]
    fn test_device_id_parse_invalid() {
        let result = DeviceId::parse("invalid-uuid");
        assert!(result.is_err());
    }
    
    #[test]
    fn test_device_id_serialization() {
        let id = DeviceId::new();
        let json = serde_json::to_string(&id).unwrap();
        
        // Should be a UUID string
        assert!(json.starts_with('"') && json.ends_with('"'));
        assert!(json.len() == 38); // 36 chars + 2 quotes
        
        let deserialized: DeviceId = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, id);
    }
    
    #[test]
    fn test_session_id_new() {
        let id1 = SessionId::new();
        let id2 = SessionId::new();
        
        // IDs should be unique
        assert_ne!(id1, id2);
    }
    
    #[test]
    fn test_session_id_parse() {
        let uuid_str = "660e8400-e29b-41d4-a716-446655440001";
        let id = SessionId::parse(uuid_str).unwrap();
        
        assert_eq!(id.as_uuid().to_string(), uuid_str);
    }
    
    #[test]
    fn test_session_id_serialization() {
        let id = SessionId::new();
        let json = serde_json::to_string(&id).unwrap();
        
        assert!(json.starts_with('"') && json.ends_with('"'));
        
        let deserialized: SessionId = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, id);
    }
    
    #[test]
    fn test_device_status_predicates() {
        assert!(DeviceStatus::Available.is_available());
        assert!(!DeviceStatus::Available.is_connecting());
        assert!(!DeviceStatus::Available.is_connected());
        assert!(!DeviceStatus::Available.is_unavailable());
        
        assert!(!DeviceStatus::Connecting.is_available());
        assert!(DeviceStatus::Connecting.is_connecting());
        assert!(!DeviceStatus::Connecting.is_connected());
        assert!(!DeviceStatus::Connecting.is_unavailable());
        
        assert!(!DeviceStatus::Connected.is_available());
        assert!(!DeviceStatus::Connected.is_connecting());
        assert!(DeviceStatus::Connected.is_connected());
        assert!(!DeviceStatus::Connected.is_unavailable());
        
        assert!(!DeviceStatus::Unavailable.is_available());
        assert!(!DeviceStatus::Unavailable.is_connecting());
        assert!(!DeviceStatus::Unavailable.is_connected());
        assert!(DeviceStatus::Unavailable.is_unavailable());
    }
    
    #[test]
    fn test_device_status_as_str() {
        assert_eq!(DeviceStatus::Available.as_str(), "available");
        assert_eq!(DeviceStatus::Connecting.as_str(), "connecting");
        assert_eq!(DeviceStatus::Connected.as_str(), "connected");
        assert_eq!(DeviceStatus::Unavailable.as_str(), "unavailable");
    }
    
    #[test]
    fn test_device_status_serialization() {
        let json = serde_json::to_string(&DeviceStatus::Available).unwrap();
        assert_eq!(json, "\"available\"");
        
        let deserialized: DeviceStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, DeviceStatus::Available);
    }
    
    #[test]
    fn test_device_status_equality() {
        assert_eq!(DeviceStatus::Available, DeviceStatus::Available);
        assert_ne!(DeviceStatus::Available, DeviceStatus::Connected);
    }
}
