//! mDNS Infrastructure
//!
//! mDNS service discovery implementation using mdns-sd.

pub mod advertiser;

pub use advertiser::{MdnsAdvertiser, MdnsConfig};
