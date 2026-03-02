//! Configuration Infrastructure
//!
//! Configuration management using the config crate.
//! Loads configuration from config.toml in the application directory.

use serde::Deserialize;
use std::path::Path;

/// Screen capture configuration
#[derive(Debug, Clone, Deserialize)]
pub struct ScreenCaptureConfig {
    /// Maximum dimension for screen capture (server will downscale if larger)
    pub max_dimension: u32,
    /// Default capture width
    pub default_width: u32,
    /// Default capture height
    pub default_height: u32,
}

impl Default for ScreenCaptureConfig {
    fn default() -> Self {
        Self {
            max_dimension: 800,
            default_width: 400,
            default_height: 300,
        }
    }
}

/// Application configuration
#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub screen_capture: ScreenCaptureConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            screen_capture: ScreenCaptureConfig::default(),
        }
    }
}

impl AppConfig {
    /// Load configuration from config.toml
    /// 
    /// Looks for config.toml in:
    /// 1. Current working directory (where .exe is run from)
    /// 2. Falls back to default values if not found
    pub fn load() -> Self {
        let config_path = Path::new("config.toml");
        
        if !config_path.exists() {
            tracing::warn!("config.toml not found, using default values");
            return Self::default();
        }
        
        match config::Config::builder()
            .add_source(config::File::from(config_path))
            .build()
        {
            Ok(cfg) => {
                match cfg.try_deserialize::<Self>() {
                    Ok(config) => {
                        tracing::info!("Loaded config.toml: max_dimension={}, default={}x{}",
                                      config.screen_capture.max_dimension,
                                      config.screen_capture.default_width,
                                      config.screen_capture.default_height);
                        config
                    }
                    Err(e) => {
                        tracing::error!("Failed to parse config.toml: {}", e);
                        tracing::warn!("Using default configuration");
                        Self::default()
                    }
                }
            }
            Err(e) => {
                tracing::error!("Failed to load config.toml: {}", e);
                tracing::warn!("Using default configuration");
                Self::default()
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = AppConfig::default();
        assert_eq!(config.screen_capture.max_dimension, 800);
        assert_eq!(config.screen_capture.default_width, 400);
        assert_eq!(config.screen_capture.default_height, 300);
    }
}
