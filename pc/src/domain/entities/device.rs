//! Device Entity
//!
//! Represents a remote device (mobile phone) that can connect to the PC.

use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

use crate::domain::value_objects::{DeviceId, DeviceStatus};

/// Represents a remote device (mobile phone)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Device {
    /// Unique device identifier
    pub id: DeviceId,
    
    /// Human-readable device name
    pub name: String,
    
    /// IP address of the device
    pub address: String,
    
    /// Port for WebSocket connection
    pub port: u16,
    
    /// WebSocket path
    pub path: String,
    
    /// Protocol version
    pub version: String,
    
    /// Current device status
    pub status: DeviceStatus,
    
    /// When the device was last seen
    pub last_seen: Option<DateTime<Utc>>,
}

impl Device {
    /// Create a new device from mDNS discovery
    pub fn from_discovery(
        name: String,
        address: String,
        port: u16,
        path: String,
        version: String,
    ) -> Self {
        Device {
            id: DeviceId::new(),
            name,
            address,
            port,
            path,
            version,
            status: DeviceStatus::Available,
            last_seen: Some(Utc::now()),
        }
    }
    
    /// Create a device with a specific ID
    pub fn with_id(mut self, id: DeviceId) -> Self {
        self.id = id;
        self
    }
    
    /// Get the WebSocket URL for this device
    pub fn websocket_url(&self) -> String {
        format!("ws://{}:{}{}", self.address, self.port, self.path)
    }
    
    /// Update the last seen timestamp
    pub fn touch(&mut self) {
        self.last_seen = Some(Utc::now());
    }
    
    /// Update device status
    pub fn set_status(&mut self, status: DeviceStatus) {
        self.status = status;
        self.touch();
    }
    
    /// Check if device is available for connection
    pub fn is_available(&self) -> bool {
        self.status.is_available()
    }
    
    /// Check if device is currently connected
    pub fn is_connected(&self) -> bool {
        self.status.is_connected()
    }
    
    /// Check if device has been seen recently (within last minute)
    pub fn is_recently_seen(&self) -> bool {
        self.last_seen
            .map(|ls| Utc::now().signed_duration_since(ls).num_seconds() < 60)
            .unwrap_or(false)
    }
}

impl std::fmt::Display for Device {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} ({})", self.name, self.address)
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
    
    #[test]
    fn test_device_from_discovery() {
        let device = create_test_device();
        
        assert_eq!(device.name, "TestPhone");
        assert_eq!(device.address, "192.168.1.100");
        assert_eq!(device.port, 8765);
        assert_eq!(device.path, "/remote");
        assert_eq!(device.version, "1.0");
        assert_eq!(device.status, DeviceStatus::Available);
        assert!(device.last_seen.is_some());
    }
    
    #[test]
    fn test_device_with_id() {
        let custom_id = DeviceId::new();
        let device = create_test_device().with_id(custom_id);
        
        assert_eq!(device.id, custom_id);
    }
    
    #[test]
    fn test_device_websocket_url() {
        let device = create_test_device();
        let url = device.websocket_url();
        
        assert_eq!(url, "ws://192.168.1.100:8765/remote");
    }
    
    #[test]
    fn test_device_touch() {
        let mut device = create_test_device();
        let before = device.last_seen.unwrap();
        
        // Sleep a tiny bit to ensure time difference
        std::thread::sleep(std::time::Duration::from_millis(10));
        device.touch();
        
        let after = device.last_seen.unwrap();
        assert!(after >= before);
    }
    
    #[test]
    fn test_device_set_status() {
        let mut device = create_test_device();
        
        device.set_status(DeviceStatus::Connecting);
        assert_eq!(device.status, DeviceStatus::Connecting);
        
        device.set_status(DeviceStatus::Connected);
        assert_eq!(device.status, DeviceStatus::Connected);
    }
    
    #[test]
    fn test_device_is_available() {
        let device = create_test_device();
        assert!(device.is_available());
        
        let mut unavailable_device = device.clone();
        unavailable_device.set_status(DeviceStatus::Unavailable);
        assert!(!unavailable_device.is_available());
    }
    
    #[test]
    fn test_device_is_connected() {
        let mut device = create_test_device();
        assert!(!device.is_connected());
        
        device.set_status(DeviceStatus::Connected);
        assert!(device.is_connected());
    }
    
    #[test]
    fn test_device_is_recently_seen() {
        let mut device = create_test_device();
        
        // Should be recently seen (just created)
        assert!(device.is_recently_seen());
        
        // Set last_seen to 2 minutes ago
        device.last_seen = Some(Utc::now() - chrono::Duration::minutes(2));
        assert!(!device.is_recently_seen());
    }
    
    #[test]
    fn test_device_display() {
        let device = create_test_device();
        let display = format!("{}", device);
        
        assert_eq!(display, "TestPhone (192.168.1.100)");
    }
    
    #[test]
    fn test_device_equality() {
        let device1 = create_test_device();
        let mut device2 = device1.clone();
        
        assert_eq!(device1, device2);
        
        device2.name = "DifferentPhone".to_string();
        assert_ne!(device1, device2);
    }
    
    #[test]
    fn test_device_serialization() {
        let device = create_test_device();
        let json = serde_json::to_string_pretty(&device).unwrap();
        
        // Should contain key fields
        assert!(json.contains("TestPhone"));
        assert!(json.contains("192.168.1.100"));
        assert!(json.contains("8765"));
        
        // Should deserialize correctly
        let deserialized: Device = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.name, device.name);
        assert_eq!(deserialized.address, device.address);
    }
}
