//! Cross-platform physical cursor position
//! 
//! Uses enigo for logical coordinates and xcap for monitor scale factors.
//! 
//! # Algorithm
//! 
//! 1. Get logical cursor position from enigo (virtual screen coordinates)
//! 2. Find which monitor contains the cursor
//! 3. Calculate physical position: `physical = (logical - monitor_origin) * scale_factor`
//! 
//! This approach works correctly on multi-monitor setups with different DPI scaling.

use xcap::Monitor;
use enigo::{Enigo, Mouse, Settings};
use tracing::{debug, error, info};

/// Get physical cursor position on the current monitor
/// 
/// Returns (monitor, physical_x, physical_y) where:
/// - `monitor` is the monitor containing the cursor
/// - `physical_x` and `physical_y` are relative to the monitor's top-left corner
///   in physical pixels (accounting for DPI scaling)
/// 
/// # Returns
/// 
/// - `Some((monitor, x, y))` if cursor position was successfully determined
/// - `None` if cursor position could not be determined
pub fn get_physical_cursor_position() -> Option<(Monitor, i32, i32)> {
    // Get logical cursor position from enigo
    let enigo = Enigo::new(&Settings::default()).ok()?;
    let (logical_x, logical_y) = enigo.location().ok()?;
    
    debug!("Logical cursor position: ({}, {})", logical_x, logical_y);
    
    // Get all monitors
    let monitors = Monitor::all().ok()?;
    
    // Find which monitor contains the cursor
    for monitor in monitors {
        let monitor_x = monitor.x().ok()?;
        let monitor_y = monitor.y().ok()?;
        let monitor_width = monitor.width().ok()?;
        let monitor_height = monitor.height().ok()?;
        let scale_factor = monitor.scale_factor().ok()?;
        
        debug!("Monitor: origin=({},{}) size={}x{} scale={}",
               monitor_x, monitor_y, monitor_width, monitor_height, scale_factor);
        
        // Convert to i32 for consistent arithmetic
        let monitor_x = monitor_x as i32;
        let monitor_y = monitor_y as i32;
        let monitor_width = monitor_width as i32;
        let monitor_height = monitor_height as i32;

        // Check if cursor is within this monitor's bounds (logical coordinates)
        if logical_x >= monitor_x &&
           logical_x < monitor_x + monitor_width &&
           logical_y >= monitor_y &&
           logical_y < monitor_y + monitor_height {

            // Calculate physical position relative to this monitor
            let physical_x = ((logical_x - monitor_x) as f32 * scale_factor) as i32;
            let physical_y = ((logical_y - monitor_y) as f32 * scale_factor) as i32;

            info!("Cursor on monitor (scale={}x): logical=({},{}) physical=({},{})",
                  scale_factor, logical_x, logical_y, physical_x, physical_y);

            return Some((monitor, physical_x, physical_y));
        }
    }
    
    error!("Cursor not found on any monitor!");
    None
}
