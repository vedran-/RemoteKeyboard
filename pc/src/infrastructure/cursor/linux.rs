//! Linux cursor position implementation
//! 
//! Currently not implemented.

use super::traits::CursorPositionProvider;

/// Linux cursor position provider
/// 
/// # Note
/// 
/// This is not yet implemented. Contributions welcome!
/// 
/// Implementation should use X11 XQueryPointer or Wayland protocol
/// to get physical screen coordinates.
pub struct LinuxCursorProvider;

impl CursorPositionProvider for LinuxCursorProvider {
    fn get_physical_position() -> Result<(i32, i32), String> {
        Err("Linux cursor position not yet implemented. Contributions welcome!".to_string())
    }
    
    fn platform_name() -> &'static str {
        "Linux (not implemented)"
    }
}
