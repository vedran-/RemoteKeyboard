//! Domain Services
//!
//! Domain services encapsulate business logic that doesn't naturally fit within entities.
//! These are interfaces (traits) that are implemented in the infrastructure layer.

pub mod input_executor;
pub mod command_handler;
pub mod connection_manager;
pub mod device_discovery;

pub use input_executor::InputExecutor;
pub use command_handler::CommandHandler;
pub use connection_manager::ConnectionManager;
pub use device_discovery::DeviceDiscovery;
