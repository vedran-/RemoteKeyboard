//! Configuration Infrastructure
//!
//! Configuration management using the config crate.
//! All screen capture settings are now controlled by the client.

use serde::Deserialize;

/// Application configuration
#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub logging: LoggingConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            logging: LoggingConfig::default(),
        }
    }
}

/// Logging configuration
#[derive(Debug, Clone, Deserialize)]
pub struct LoggingConfig {
    /// Log level: error, warn, info, debug, trace
    pub level: String,
}

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            level: "info".to_string(),
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
        // Config file is optional now - all settings controlled by client
        let config_path = std::path::Path::new("config.toml");

        if config_path.exists() {
            match config::Config::builder()
                .add_source(config::File::from(config_path).format(config::FileFormat::Toml))
                .build()
            {
                Ok(cfg) => {
                    if let Ok(config) = cfg.try_deserialize::<Self>() {
                        tracing::info!("Loaded config.toml: log_level={}", config.logging.level);
                        return config;
                    }
                }
                Err(e) => {
                    tracing::warn!("Failed to load config.toml: {}", e);
                }
            }
        }

        tracing::info!("Using default configuration (log_level=info)");
        Self::default()
    }

    /// Get the logging level as a string for tracing subscriber
    pub fn get_log_level(&self) -> &str {
        &self.logging.level
    }
}
