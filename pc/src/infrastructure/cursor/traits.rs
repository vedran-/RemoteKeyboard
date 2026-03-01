/// Platform-specific cursor position provider
/// 
/// This trait defines the interface for getting physical cursor coordinates
/// on different platforms. Each platform implementation should return
/// coordinates in physical pixels.
pub trait CursorPositionProvider {
    /// Get cursor position in physical screen coordinates
    /// 
    /// Returns (x, y) in physical pixels from top-left of virtual screen
    /// 
    /// # Errors
    /// 
    /// Returns an error if the cursor position cannot be determined
    fn get_physical_position() -> Result<(i32, i32), String>;
    
    /// Get the platform name for logging/debugging
    fn platform_name() -> &'static str;
}
