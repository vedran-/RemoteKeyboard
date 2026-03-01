//! macOS cursor position implementation
//! 
//! Currently not implemented.

use super::traits::CursorPositionProvider;

/// macOS cursor position provider
/// 
/// # Note
/// 
/// This is not yet implemented. Contributions welcome!
/// 
/// Implementation should use CoreGraphics CGEventGetLocation
/// to get physical screen coordinates.
pub struct MacOsCursorProvider;

impl CursorPositionProvider for MacOsCursorProvider {
    fn get_physical_position() -> Result<(i32, i32), String> {
        Err("macOS cursor position not yet implemented. Contributions welcome!".to_string())
    }
    
    fn platform_name() -> &'static str {
        "macOS (not implemented)"
    }
}
