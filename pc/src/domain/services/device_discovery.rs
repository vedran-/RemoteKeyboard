//! Device Discovery Port
//!
//! Trait for discovering devices on the local network.

use crate::domain::entities::Device;
use crate::application::ports::Result;
use tokio_stream::Stream;

/// Trait for device discovery
#[async_trait::async_trait]
pub trait DeviceDiscovery: Send + Sync {
    /// Start advertising this device (PC) on the network
    fn advertise(&self) -> Result<()>;
    
    /// Stop advertising
    fn stop_advertising(&self) -> Result<()>;
    
    /// Start discovering devices (returns a stream)
    fn discover(&self) -> Result<Box<dyn Stream<Item = Result<Device>> + Send + Unpin>>;
    
    /// Check if advertising is active
    fn is_advertising(&self) -> bool;
}
