//! mDNS Service Advertiser
//!
//! Advertises the PC on the local network using mDNS (RFC 6762)
//! so mobile devices can discover it automatically.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use mdns_sd::{ServiceDaemon, ServiceInfo};
use tracing::{debug, error, info, warn};

use crate::application::ports::{Result, Error};

/// mDNS service configuration
#[derive(Debug, Clone)]
pub struct MdnsConfig {
    /// Service type (e.g., "_remotekeyboard._tcp.local.")
    pub service_type: String,
    /// Instance name (e.g., "LivingRoom-PC")
    pub instance_name: String,
    /// Hostname (usually the PC's hostname)
    pub hostname: String,
    /// Port number for WebSocket connections
    pub port: u16,
    /// Service version
    pub version: String,
    /// WebSocket path
    pub path: String,
}

impl Default for MdnsConfig {
    fn default() -> Self {
        MdnsConfig {
            service_type: "_remotekeyboard._tcp.local.".to_string(),
            instance_name: "RemoteKeyboard PC".to_string(),
            hostname: format!("{}.local.", hostname::get().unwrap_or_default().to_string_lossy()),
            port: 8765,
            version: "1.0".to_string(),
            path: "/remote".to_string(),
        }
    }
}

/// mDNS Service Advertiser
pub struct MdnsAdvertiser {
    daemon: ServiceDaemon,
    service_info: Arc<Mutex<Option<String>>>, // Store service fullname for unregister
    config: MdnsConfig,
    is_advertising: Arc<AtomicBool>,
}

impl MdnsAdvertiser {
    /// Create a new mDNS advertiser
    pub fn new(config: MdnsConfig) -> Result<Self> {
        let daemon = ServiceDaemon::new()
            .map_err(|e| Error::network(format!("Failed to create mDNS daemon: {}", e)))?;
        
        Ok(MdnsAdvertiser {
            daemon,
            service_info: Arc::new(Mutex::new(None)),
            config,
            is_advertising: Arc::new(AtomicBool::new(false)),
        })
    }
    
    /// Start advertising the service
    pub fn advertise(&self) -> Result<()> {
        if self.is_advertising.load(Ordering::SeqCst) {
            warn!("mDNS service is already advertising");
            return Ok(());
        }
        
        // Create TXT records with service metadata
        let properties = vec![
            ("version", self.config.version.as_str()),
            ("name", self.config.instance_name.as_str()),
            ("protocol", "websocket"),
            ("path", self.config.path.as_str()),
        ];
        
        // Create service info - mdns-sd 0.11 API requires 6 arguments
        let service_info = ServiceInfo::new(
            &self.config.service_type,
            &self.config.instance_name,
            &self.config.hostname,
            "",  // Empty string for addr_auto
            self.config.port,
            &properties[..],
        )
        .map_err(|e| Error::network(format!("Failed to create service info: {}", e)))?
        .enable_addr_auto();
        
        // Get the fullname before moving
        let fullname = service_info.get_fullname().to_string();
        
        // Register the service
        self.daemon
            .register(service_info)
            .map_err(|e| Error::network(format!("Failed to register mDNS service: {}", e)))?;
        
        info!(
            "Advertising mDNS service: {} ({}:{})",
            self.config.instance_name,
            self.config.hostname,
            self.config.port
        );
        
        *self.service_info.lock().unwrap() = Some(fullname);
        self.is_advertising.store(true, Ordering::SeqCst);
        
        Ok(())
    }
    
    /// Stop advertising the service
    pub fn stop_advertising(&self) -> Result<()> {
        if !self.is_advertising.load(Ordering::SeqCst) {
            debug!("mDNS service is not advertising");
            return Ok(());
        }
        
        let guard = self.service_info.lock().unwrap();
        if let Some(fullname) = guard.as_ref() {
            self.daemon
                .unregister(fullname)
                .map_err(|e| Error::network(format!("Failed to unregister mDNS service: {}", e)))?;
            
            info!("Stopped advertising mDNS service");
        }
        
        drop(guard);
        *self.service_info.lock().unwrap() = None;
        self.is_advertising.store(false, Ordering::SeqCst);
        
        Ok(())
    }
    
    /// Check if currently advertising
    pub fn is_advertising(&self) -> bool {
        self.is_advertising.load(Ordering::SeqCst)
    }
    
    /// Get the service configuration
    pub fn config(&self) -> &MdnsConfig {
        &self.config
    }
    
    /// Get the full service name
    pub fn service_name(&self) -> Option<String> {
        self.service_info.lock().unwrap().clone()
    }
}

impl Drop for MdnsAdvertiser {
    fn drop(&mut self) {
        if let Err(e) = self.stop_advertising() {
            error!("Failed to stop mDNS advertising on drop: {}", e);
        }
        
        // Shutdown the daemon
        if let Err(e) = self.daemon.shutdown() {
            error!("Failed to shutdown mDNS daemon: {}", e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    fn create_test_config() -> MdnsConfig {
        MdnsConfig {
            service_type: "_test-remotekeyboard._tcp.local.".to_string(),
            instance_name: "TestPC".to_string(),
            hostname: "testpc.local.".to_string(),
            port: 8766,
            version: "1.0".to_string(),
            path: "/remote".to_string(),
        }
    }
    
    #[test]
    fn test_mdns_config_default() {
        let config = MdnsConfig::default();
        
        assert_eq!(config.service_type, "_remotekeyboard._tcp.local.");
        assert_eq!(config.port, 8765);
        assert_eq!(config.version, "1.0");
        assert_eq!(config.path, "/remote");
    }
    
    #[test]
    fn test_mdns_advertiser_creation() {
        let config = create_test_config();
        let advertiser = MdnsAdvertiser::new(config.clone());
        
        assert!(advertiser.is_ok());
        let advertiser = advertiser.unwrap();
        
        assert!(!advertiser.is_advertising());
        assert_eq!(advertiser.config().port, config.port);
    }
    
    #[test]
    fn test_mdns_advertise_and_stop() {
        let config = create_test_config();
        let advertiser = MdnsAdvertiser::new(config).unwrap();
        
        // Initially not advertising
        assert!(!advertiser.is_advertising());
        
        // Start advertising
        let result = advertiser.advertise();
        assert!(result.is_ok());
        assert!(advertiser.is_advertising());
        
        // Should have a service name
        assert!(advertiser.service_name().is_some());
        
        // Stop advertising
        let result = advertiser.stop_advertising();
        assert!(result.is_ok());
        assert!(!advertiser.is_advertising());
    }
    
    #[test]
    fn test_mdns_double_advertise() {
        let config = create_test_config();
        let advertiser = MdnsAdvertiser::new(config).unwrap();
        
        // Advertise twice - should not fail
        assert!(advertiser.advertise().is_ok());
        assert!(advertiser.advertise().is_ok()); // Second call should be OK
        
        assert!(advertiser.is_advertising());
    }
    
    #[test]
    fn test_mdns_stop_without_advertise() {
        let config = create_test_config();
        let advertiser = MdnsAdvertiser::new(config).unwrap();
        
        // Stop without advertising - should be OK
        assert!(advertiser.stop_advertising().is_ok());
        assert!(!advertiser.is_advertising());
    }
    
    #[test]
    fn test_mdns_drop_cleanup() {
        let config = create_test_config();
        {
            let advertiser = MdnsAdvertiser::new(config).unwrap();
            advertiser.advertise().unwrap();
            assert!(advertiser.is_advertising());
            // advertiser goes out of scope here, Drop should clean up
        }
        // Test passes if no panic
    }
}
