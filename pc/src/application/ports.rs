//! Application Ports
//!
//! Common types used across application layer ports.

use thiserror::Error;

/// Application result type
pub type Result<T> = std::result::Result<T, Error>;

/// Application error types
#[derive(Error, Debug)]
pub enum Error {
    #[error("Connection error: {0}")]
    Connection(String),
    
    #[error("Device error: {0}")]
    Device(String),
    
    #[error("Input error: {0}")]
    Input(String),
    
    #[error("Network error: {0}")]
    Network(String),
    
    #[error("Protocol error: {0}")]
    Protocol(String),
    
    #[error("Configuration error: {0}")]
    Configuration(String),
    
    #[error("Internal error: {0}")]
    Internal(String),
}

impl Error {
    pub fn connection(msg: impl Into<String>) -> Self {
        Error::Connection(msg.into())
    }
    
    pub fn device(msg: impl Into<String>) -> Self {
        Error::Device(msg.into())
    }
    
    pub fn input(msg: impl Into<String>) -> Self {
        Error::Input(msg.into())
    }
    
    pub fn network(msg: impl Into<String>) -> Self {
        Error::Network(msg.into())
    }
    
    pub fn protocol(msg: impl Into<String>) -> Self {
        Error::Protocol(msg.into())
    }
    
    pub fn configuration(msg: impl Into<String>) -> Self {
        Error::Configuration(msg.into())
    }
    
    pub fn internal(msg: impl Into<String>) -> Self {
        Error::Internal(msg.into())
    }
}

// Convert from other error types
impl From<serde_json::Error> for Error {
    fn from(err: serde_json::Error) -> Self {
        Error::protocol(format!("JSON error: {}", err))
    }
}

impl From<uuid::Error> for Error {
    fn from(err: uuid::Error) -> Self {
        Error::protocol(format!("UUID error: {}", err))
    }
}

impl From<std::io::Error> for Error {
    fn from(err: std::io::Error) -> Self {
        Error::network(format!("IO error: {}", err))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_error_display() {
        let err = Error::connection("Connection failed");
        assert_eq!(format!("{}", err), "Connection error: Connection failed");
        
        let err = Error::device("Device not found");
        assert_eq!(format!("{}", err), "Device error: Device not found");
        
        let err = Error::input("Failed to simulate input");
        assert_eq!(format!("{}", err), "Input error: Failed to simulate input");
    }
    
    #[test]
    fn test_error_from_serde_json() {
        let json_err = serde_json::from_str::<serde_json::Value>("invalid").unwrap_err();
        let err: Error = json_err.into();
        
        match err {
            Error::Protocol(msg) => {
                assert!(msg.contains("JSON error"));
            }
            _ => panic!("Expected Protocol error"),
        }
    }
    
    #[test]
    fn test_error_from_uuid() {
        let uuid_err = uuid::Uuid::parse_str("invalid").unwrap_err();
        let err: Error = uuid_err.into();
        
        match err {
            Error::Protocol(msg) => {
                assert!(msg.contains("UUID error"));
            }
            _ => panic!("Expected Protocol error"),
        }
    }
    
    #[test]
    fn test_error_from_io() {
        let io_err = std::io::Error::new(std::io::ErrorKind::ConnectionRefused, "refused");
        let err: Error = io_err.into();
        
        match err {
            Error::Network(msg) => {
                assert!(msg.contains("IO error"));
            }
            _ => panic!("Expected Network error"),
        }
    }
}
