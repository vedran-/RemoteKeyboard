//! Cross-platform cursor position module
//! 
//! Provides physical cursor coordinates across all platforms.
//! 
//! # Platform Support
//! 
//! | Platform | Status | Implementation |
//! |----------|--------|----------------|
//! | Windows | ✅ Supported | GetPhysicalCursorPos |
//! | Linux | ❌ Not implemented | - |
//! | macOS | ❌ Not implemented | - |

mod traits;

#[cfg(target_os = "windows")]
mod windows;

#[cfg(target_os = "linux")]
mod linux;

#[cfg(target_os = "macos")]
mod macos;

pub use traits::CursorPositionProvider;

/// Get cursor position in physical screen coordinates
/// 
/// Returns (x, y) in physical pixels from top-left of virtual screen
/// 
/// # Errors
/// 
/// Returns an error if:
/// - The platform is not supported
/// - The platform implementation fails to get the cursor position
pub fn get_physical_cursor_position() -> Result<(i32, i32), String> {
    #[cfg(target_os = "windows")]
    {
        windows::WindowsCursorProvider::get_physical_position()
    }
    
    #[cfg(target_os = "linux")]
    {
        linux::LinuxCursorProvider::get_physical_position()
    }
    
    #[cfg(target_os = "macos")]
    {
        macos::MacOsCursorProvider::get_physical_position()
    }
    
    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        Err(format!("Unsupported platform: {}", std::env::consts::OS))
    }
}

/// Get the current platform name for logging
pub fn get_platform_name() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        windows::WindowsCursorProvider::platform_name()
    }
    
    #[cfg(target_os = "linux")]
    {
        linux::LinuxCursorProvider::platform_name()
    }
    
    #[cfg(target_os = "macos")]
    {
        macos::MacOsCursorProvider::platform_name()
    }
    
    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        "Unknown"
    }
}
