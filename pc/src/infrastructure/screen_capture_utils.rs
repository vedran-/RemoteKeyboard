//! Screen Capture Utilities - Working Version
//!
//! Uses Windows API (winapi) for cursor position + monitor bounds
//! Uses windows-capture for actual screen capture with cursor

use std::sync::mpsc;
use image::RgbaImage;
use windows_capture::{
    capture::{Context, GraphicsCaptureApiHandler},
    frame::Frame,
    graphics_capture_api::InternalCaptureControl,
    monitor::Monitor,
    settings::{
        ColorFormat, CursorCaptureSettings, DirtyRegionSettings, DrawBorderSettings,
        MinimumUpdateIntervalSettings, SecondaryWindowSettings, Settings,
    },
};

// Windows API imports (winapi crate)
#[cfg(target_os = "windows")]
use winapi::{
    shared::windef::{POINT, RECT, HMONITOR, HDC, LPRECT},
    shared::minwindef::{LPARAM, BOOL},
    um::winuser::{GetCursorPos, GetMonitorInfoW, MonitorFromPoint, MONITORINFOEXW, MONITOR_DEFAULTTONEAREST},
};
#[cfg(target_os = "windows")]
use std::ffi::c_void;

// Callback data for EnumDisplayMonitors
#[cfg(target_os = "windows")]
struct MonitorEnumData {
    monitors: Vec<(HMONITOR, RECT)>,
}

// Callback function for EnumDisplayMonitors
#[cfg(target_os = "windows")]
unsafe extern "system" fn monitor_enum_proc(
    hmonitor: HMONITOR,
    _hdcmonitor: HDC,
    _lprcmonitor: LPRECT,
    lparam: LPARAM,
) -> BOOL {
    let data = &mut *(lparam as *mut MonitorEnumData);
    let mut mi = MONITORINFOEXW {
        cbSize: std::mem::size_of::<MONITORINFOEXW>() as u32,
        rcMonitor: RECT { left: 0, top: 0, right: 0, bottom: 0 },
        rcWork: RECT { left: 0, top: 0, right: 0, bottom: 0 },
        dwFlags: 0,
        szDevice: [0; 32],
    };
    GetMonitorInfoW(hmonitor, &mut mi as *mut _ as *mut _);
    data.monitors.push((hmonitor, mi.rcMonitor));
    1 // Continue enumeration
}

/// Get all monitors with their physical bounds in virtual screen coordinates
#[cfg(target_os = "windows")]
fn get_all_monitors() -> Result<Vec<(Monitor, i32, i32, i32, i32)>, Box<dyn std::error::Error>> {
    let mut enum_data = MonitorEnumData {
        monitors: Vec::new(),
    };
    
    unsafe {
        // Use proper EnumDisplayMonitors Windows API
        winapi::um::winuser::EnumDisplayMonitors(
            std::ptr::null_mut(),
            std::ptr::null(),
            Some(monitor_enum_proc),
            &mut enum_data as *mut _ as isize,
        );
    }
    
    // Convert to our format with windows-capture Monitor objects
    let mut result = Vec::new();
    for (hmonitor, rect) in enum_data.monitors {
        // Create windows-capture Monitor from HMONITOR handle
        let monitor = Monitor::from_raw_hmonitor(hmonitor as *mut c_void);
        result.push((
            monitor,
            rect.left,
            rect.top,
            rect.right,
            rect.bottom,
        ));
    }
    
    Ok(result)
}

// --- DATA STRUCTURES ---

#[derive(Clone)]
#[allow(dead_code)]  // Used for future multi-monitor enhancements
struct CaptureRequest {
    global_x: i32,
    global_y: i32,
    width: u32,
    height: u32,
}

struct FrameData {
    pixels: Vec<u8>,
    #[allow(dead_code)]
    monitor_x: i32,
    #[allow(dead_code)]
    monitor_y: i32,
    #[allow(dead_code)]
    monitor_width: u32,
    #[allow(dead_code)]
    monitor_height: u32,
    #[allow(dead_code)]
    crop_x: i32,
    #[allow(dead_code)]
    crop_y: i32,
    crop_width: u32,
    crop_height: u32,
    canvas_offset_x: u32,  // Where this frame goes on the canvas
    canvas_offset_y: u32,
}

// --- CAPTURE HANDLER ---

struct SingleFrameHandler {
    tx: mpsc::Sender<FrameData>,
    monitor_info: (i32, i32, u32, u32, i32, i32, u32, u32, u32, u32), // mx, my, mw, mh, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y
}

impl GraphicsCaptureApiHandler for SingleFrameHandler {
    type Flags = (mpsc::Sender<FrameData>, (i32, i32, u32, u32, i32, i32, u32, u32, u32, u32));
    type Error = Box<dyn std::error::Error + Send + Sync>;

    fn new(ctx: Context<Self::Flags>) -> Result<Self, Self::Error> {
        Ok(Self { 
            tx: ctx.flags.0, 
            monitor_info: ctx.flags.1 
        })
    }

    fn on_frame_arrived(
        &mut self,
        frame: &mut Frame,
        capture_control: InternalCaptureControl
    ) -> Result<(), Self::Error> {
        let (mx, my, mw, mh, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y) = self.monitor_info;

        // Get ACTUAL frame dimensions from the frame itself
        let frame_width = frame.width();
        let frame_height = frame.height();

        // Get buffer data
        let mut buffer = frame.buffer()?;
        let nopadding_buffer = buffer.as_nopadding_buffer()?;
        let full_pixels = nopadding_buffer.to_vec();

        // Calculate actual bytes per pixel
        let calc_bpp = full_pixels.len() / (frame_width * frame_height) as usize;

        tracing::debug!(
            "Frame: actual={}x{}, monitor_info={}x{}, buffer={} bytes, bpp={}",
            frame_width, frame_height, mw, mh, full_pixels.len(), calc_bpp
        );

        // crop_x, crop_y are already in PHYSICAL coordinates (relative to monitor origin)
        // Allow negative and out-of-bounds coordinates - crop_image fills with black
        let physical_crop_x = crop_x;  // No clamping - cursor stays centered
        let physical_crop_y = crop_y;

        tracing::debug!("Crop (physical): ({},{}) size={}x{}",
                       physical_crop_x, physical_crop_y, crop_w, crop_h);

        // Crop to requested region using PHYSICAL coordinates
        let crop_pixels = crop_image(
            &full_pixels,
            frame_width, frame_height,
            physical_crop_x, physical_crop_y,
            crop_w, crop_h,
            calc_bpp as u32,
        );

        tracing::debug!(
            "Cropped to: {}x{} = {} pixels, crop_buffer = {} bytes",
            crop_w, crop_h, crop_w * crop_h, crop_pixels.len()
        );

        let _ = self.tx.send(FrameData {
            pixels: crop_pixels,
            monitor_x: mx,
            monitor_y: my,
            monitor_width: mw,
            monitor_height: mh,
            crop_x,
            crop_y,
            crop_width: crop_w,
            crop_height: crop_h,
            canvas_offset_x: canvas_x,
            canvas_offset_y: canvas_y,
        });

        capture_control.stop();
        Ok(())
    }

    fn on_closed(&mut self) -> Result<(), Self::Error> {
        Ok(())
    }
}

// --- HELPER FUNCTIONS ---

/// Get cursor position in virtual screen coordinates using Windows API
#[cfg(target_os = "windows")]
fn get_cursor_position() -> Result<(i32, i32), Box<dyn std::error::Error>> {
    let mut point = POINT { x: 0, y: 0 };
    unsafe {
        if GetCursorPos(&mut point) != 0 {
            Ok((point.x, point.y))
        } else {
            Err("Failed to get cursor position".into())
        }
    }
}

/// Get monitor at cursor position with its bounds
/// Returns (Monitor, left, top, right, bottom) in virtual screen coordinates
#[allow(dead_code)]  // Used for single-monitor fallback
fn get_monitor_at_cursor() -> Result<(Monitor, i32, i32, i32, i32), Box<dyn std::error::Error>> {
    // Get cursor position
    let (cursor_x, cursor_y) = get_cursor_position()?;
    
    unsafe {
        let point = POINT { x: cursor_x, y: cursor_y };
        let hmonitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
        
        // Get bounds from Windows API
        let mut mi = std::mem::zeroed::<MONITORINFOEXW>();
        mi.cbSize = std::mem::size_of::<MONITORINFOEXW>() as u32;
        GetMonitorInfoW(hmonitor as *mut _, &mut mi as *mut _ as *mut _);
        
        let (left, top, right, bottom) = (
            mi.rcMonitor.left,
            mi.rcMonitor.top,
            mi.rcMonitor.right,
            mi.rcMonitor.bottom,
        );
        
        tracing::debug!("Windows API: monitor at cursor is {}x{} at ({},{})", 
                      right - left, bottom - top, left, top);
        
        // Create windows-capture Monitor directly from HMONITOR handle
        let monitor = Monitor::from_raw_hmonitor(hmonitor as *mut std::ffi::c_void);
        
        let m_width = monitor.width()? as i32;
        let m_height = monitor.height()? as i32;
        
        tracing::debug!("windows-capture: monitor is {}x{} (physical pixels)", m_width, m_height);
        
        Ok((monitor, left, top, right, bottom))
    }
}

/// Crop an image from full monitor capture
fn crop_image(
    pixels: &[u8],
    full_width: u32,
    full_height: u32,
    crop_x: i32,
    crop_y: i32,
    crop_width: u32,
    crop_height: u32,
    bytes_per_pixel: u32,
) -> Vec<u8> {
    let mut result = Vec::with_capacity((crop_width * crop_height * bytes_per_pixel) as usize);
    
    for y in 0..crop_height {
        let abs_y = crop_y + y as i32;
        if abs_y < 0 || abs_y >= full_height as i32 {
            // Fill with black for out-of-bounds rows
            result.extend(std::iter::repeat(0u8).take((crop_width * bytes_per_pixel) as usize));
            continue;
        }
        
        for x in 0..crop_width {
            let abs_x = crop_x + x as i32;
            if abs_x < 0 || abs_x >= full_width as i32 {
                // Fill with black for out-of-bounds pixels
                result.extend(std::iter::repeat(0u8).take(bytes_per_pixel as usize));
            } else {
                let src_idx = ((abs_y as u32 * full_width + abs_x as u32) * bytes_per_pixel) as usize;
                result.extend_from_slice(&pixels[src_idx..src_idx + bytes_per_pixel as usize]);
            }
        }
    }
    
    result
}

// --- THE MAIN API ---

pub fn get_screen_area_around_cursor(
    width: u32,
    height: u32
) -> Result<RgbaImage, Box<dyn std::error::Error>> {
    tracing::debug!("Capture request: {}x{}", width, height);

    // 1. Get cursor position in LOGICAL coordinates (Windows API)
    let (cursor_logical_x, cursor_logical_y) = get_cursor_position()?;
    tracing::debug!("Cursor position (logical): ({}, {})", cursor_logical_x, cursor_logical_y);

    // 2. Get ALL monitors with their bounds
    let all_monitors = get_all_monitors()?;
    tracing::debug!("Found {} monitor(s)", all_monitors.len());
    
    // 3. Find cursor's monitor and get its scale (this is our reference scale)
    let cursor_monitor_info = all_monitors.iter()
        .find(|(_, m_left, m_top, m_right, m_bottom)| {
            cursor_logical_x >= *m_left && cursor_logical_x < *m_right &&
            cursor_logical_y >= *m_top && cursor_logical_y < *m_bottom
        });
    
    let (cursor_scale_x, cursor_scale_y) = cursor_monitor_info
        .map(|(monitor, m_left, m_top, m_right, m_bottom)| {
            let logical_w = (m_right - m_left) as f32;
            let logical_h = (m_bottom - m_top) as f32;
            let physical_w = monitor.width().unwrap_or(1920) as f32;
            let physical_h = monitor.height().unwrap_or(1080) as f32;
            (physical_w / logical_w, physical_h / logical_h)
        })
        .unwrap_or((1.0, 1.0));
    
    tracing::debug!("Cursor monitor scale: ({:.2}, {:.2})", cursor_scale_x, cursor_scale_y);
    
    // 4. Convert cursor to PHYSICAL coordinates
    let cursor_phys_x = (cursor_logical_x as f32 * cursor_scale_x) as i32;
    let cursor_phys_y = (cursor_logical_y as f32 * cursor_scale_y) as i32;
    
    tracing::debug!("Cursor position (physical): ({}, {})", cursor_phys_x, cursor_phys_y);
    
    // 5. Define capture region in PHYSICAL coordinates (centered on cursor)
    let capture_left_phys = cursor_phys_x - (width as i32 / 2);
    let capture_top_phys = cursor_phys_y - (height as i32 / 2);
    let capture_right_phys = capture_left_phys + width as i32;
    let capture_bottom_phys = capture_top_phys + height as i32;
    
    tracing::debug!("Capture region (physical): ({},{}) to ({},{})", 
                  capture_left_phys, capture_top_phys,
                  capture_right_phys, capture_bottom_phys);

    // 6. Find all monitors that intersect with capture region (in PHYSICAL coords)
    let mut relevant_monitors = Vec::new();
    
    tracing::debug!("Checking {} monitor(s) for intersection with capture region", all_monitors.len());
    
    for (monitor, m_left_logical, m_top_logical, m_right_logical, m_bottom_logical) in all_monitors {
        // Get this monitor's scale and physical bounds
        let monitor_logical_width = m_right_logical - m_left_logical;
        let monitor_logical_height = m_bottom_logical - m_top_logical;
        let monitor_physical_width = monitor.width()? as i32;
        let monitor_physical_height = monitor.height()? as i32;
        let scale_x = monitor_physical_width as f32 / monitor_logical_width as f32;
        let scale_y = monitor_physical_height as f32 / monitor_logical_height as f32;
        
        // Monitor's physical bounds in global physical coordinate space
        // For simplicity, we treat each monitor's physical space as starting at (0,0) for that monitor
        // But we need to track the global physical position for proper stitching
        
        // The monitor's top-left in global physical coords
        let monitor_phys_left = (m_left_logical as f32 * scale_x) as i32;
        let monitor_phys_top = (m_top_logical as f32 * scale_y) as i32;
        let monitor_phys_right = monitor_phys_left + monitor_physical_width;
        let monitor_phys_bottom = monitor_phys_top + monitor_physical_height;
        
        tracing::debug!("Monitor: logical=({},{})-({},{}) physical=({},{})-({},{}) scale=({:.2},{:.2})",
                      m_left_logical, m_top_logical, m_right_logical, m_bottom_logical,
                      monitor_phys_left, monitor_phys_top, monitor_phys_right, monitor_phys_bottom,
                      scale_x, scale_y);
        
        // Check if capture region (in physical coords) intersects with this monitor's physical bounds
        let intersects = !(
            capture_right_phys <= monitor_phys_left ||   // Capture is entirely to the left
            capture_left_phys >= monitor_phys_right ||   // Capture is entirely to the right
            capture_bottom_phys <= monitor_phys_top ||   // Capture is entirely above
            capture_top_phys >= monitor_phys_bottom      // Capture is entirely below
        );
        
        tracing::debug!("  Capture physical=({},{})-({},{}) intersects={}",
                      capture_left_phys, capture_top_phys,
                      capture_right_phys, capture_bottom_phys,
                      intersects);
        
        if intersects {
            // Calculate overlap in PHYSICAL coordinates
            let overlap_left = capture_left_phys.max(monitor_phys_left);
            let overlap_top = capture_top_phys.max(monitor_phys_top);
            let overlap_right = capture_right_phys.min(monitor_phys_right);
            let overlap_bottom = capture_bottom_phys.min(monitor_phys_bottom);
            
            // Crop region is the overlap, relative to this monitor's origin (in physical coords)
            let physical_crop_x = overlap_left - monitor_phys_left;
            let physical_crop_y = overlap_top - monitor_phys_top;
            let physical_crop_w = (overlap_right - overlap_left) as u32;
            let physical_crop_h = (overlap_bottom - overlap_top) as u32;
            
            // Canvas position: where does this monitor's portion go on final image?
            // We need to convert from global physical to canvas coordinates
            // Canvas is in "cursor scale" logical coordinates
            let canvas_x = ((overlap_left - capture_left_phys) as f32).round().max(0.0) as u32;
            let canvas_y = ((overlap_top - capture_top_phys) as f32).round().max(0.0) as u32;
            
            tracing::debug!("  Overlap: physical=({},{})-({},{}) crop=({},{}) {}x{} canvas=({},{})",
                          overlap_left, overlap_top, overlap_right, overlap_bottom,
                          physical_crop_x, physical_crop_y,
                          physical_crop_w, physical_crop_h,
                          canvas_x, canvas_y);
            
            relevant_monitors.push((
                monitor,
                physical_crop_x,
                physical_crop_y,
                physical_crop_w,
                physical_crop_h,
                canvas_x,
                canvas_y,
                scale_x,
                scale_y,
            ));
        }
    }

    // 5. Capture frames from all intersecting monitors
    let (tx, rx) = mpsc::channel();
    let num_monitors = relevant_monitors.len();
    let mut _capture_controls = Vec::new();

    for (monitor, physical_crop_x, physical_crop_y, physical_crop_w, physical_crop_h, 
         canvas_x, canvas_y, _scale_x, _scale_y) in relevant_monitors {
        let tx_clone = tx.clone();
        
        let monitor_physical_width = monitor.width()? as u32;
        let monitor_physical_height = monitor.height()? as u32;
        
        // Pass scale factors to handler for proper scaling during stitching
        let settings = Settings::new(
            monitor,
            CursorCaptureSettings::WithCursor,
            DrawBorderSettings::Default,
            SecondaryWindowSettings::Default,
            MinimumUpdateIntervalSettings::Default,
            DirtyRegionSettings::Default,
            ColorFormat::Bgra8,
            (tx_clone, (
                0, 0,  // mx, my (not used)
                monitor_physical_width,
                monitor_physical_height,
                physical_crop_x,
                physical_crop_y,
                physical_crop_w,
                physical_crop_h,
                canvas_x,
                canvas_y,
            )),
        );

        match SingleFrameHandler::start_free_threaded(settings) {
            Ok(capture_control) => {
                _capture_controls.push(capture_control);
            }
            Err(e) => {
                tracing::error!("Failed to start screen capture: {}", e);
                return Err(Box::new(e));
            }
        }
    }

    // 6. Stitch results from all monitors
    let mut canvas = RgbaImage::new(width, height);
    
    // Fill canvas with black first (for areas not covered by any monitor)
    for y in 0..height {
        for x in 0..width {
            canvas.put_pixel(x, y, image::Rgba([0, 0, 0, 255]));
        }
    }
    
    for i in 0..num_monitors {
        let frame = rx.recv()?;
        let expected_bytes = (frame.crop_width * frame.crop_height * 4) as usize;
        
        tracing::debug!(
            "Received frame #{}: {}x{} pixels, data={} bytes, expected={} bytes, canvas_offset=({},{})",
            i, frame.crop_width, frame.crop_height,
            frame.pixels.len(),
            expected_bytes,
            frame.canvas_offset_x, frame.canvas_offset_y
        );
        
        // Convert BGRA to RGBA
        let mut rgba_pixels = Vec::with_capacity(frame.pixels.len());
        for bgra in frame.pixels.chunks(4) {
            if bgra.len() == 4 {
                rgba_pixels.push(bgra[2]); // R
                rgba_pixels.push(bgra[1]); // G
                rgba_pixels.push(bgra[0]); // B
                rgba_pixels.push(bgra[3]); // A
            }
        }
        
        let physical_img = RgbaImage::from_raw(frame.crop_width, frame.crop_height, rgba_pixels)
            .ok_or_else(|| {
                format!(
                    "Failed to create image: {}x{} needs {} bytes but got {} bytes",
                    frame.crop_width, frame.crop_height,
                    expected_bytes,
                    frame.pixels.len()
                )
            })?;
        
        // Scale physical image to logical size for proper canvas positioning
        // This ensures cursor is centered regardless of monitor DPI
        let logical_crop_w = ((frame.crop_width as f32)).round() as u32;
        let logical_crop_h = ((frame.crop_height as f32)).round() as u32;
        
        let monitor_img = if logical_crop_w != frame.crop_width || logical_crop_h != frame.crop_height {
            // Scale to logical size (matching cursor's monitor scale)
            image::imageops::resize(
                &physical_img,
                logical_crop_w,
                logical_crop_h,
                image::imageops::Triangle,
            )
        } else {
            physical_img
        };
        
        tracing::debug!("Successfully captured {}x{} (scaled to {}x{}) from monitor at canvas ({},{})", 
                      frame.crop_width, frame.crop_height,
                      monitor_img.width(), monitor_img.height(),
                      frame.canvas_offset_x, frame.canvas_offset_y);

        // Copy pixels to canvas at correct position (now both in logical coordinates)
        for local_y in 0..monitor_img.height() {
            for local_x in 0..monitor_img.width() {
                let canvas_x = frame.canvas_offset_x + local_x;
                let canvas_y = frame.canvas_offset_y + local_y;
                
                if canvas_x < width && canvas_y < height {
                    let pixel = monitor_img.get_pixel(local_x, local_y);
                    canvas.put_pixel(canvas_x, canvas_y, *pixel);
                }
            }
        }
    }

    Ok(canvas)
}
