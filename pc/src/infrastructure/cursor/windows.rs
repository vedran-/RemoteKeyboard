//! Windows cursor position implementation
//! 
//! Uses GetPhysicalCursorPos() to get physical screen coordinates.

use super::traits::CursorPositionProvider;

/// Windows cursor position provider using GetPhysicalCursorPos
pub struct WindowsCursorProvider;

impl CursorPositionProvider for WindowsCursorProvider {
    fn get_physical_position() -> Result<(i32, i32), String> {
        use windows::Win32::UI::WindowsAndMessaging::GetPhysicalCursorPos;
        use windows::Win32::Foundation::POINT;
        
        let mut point = POINT { x: 0, y: 0 };
        unsafe {
            if GetPhysicalCursorPos(&mut point).is_ok() {
                Ok((point.x, point.y))
            } else {
                Err("Failed to get physical cursor position".to_string())
            }
        }
    }
    
    fn platform_name() -> &'static str {
        "Windows (GetPhysicalCursorPos)"
    }
}
