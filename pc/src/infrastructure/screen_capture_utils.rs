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
    shared::windef::POINT,
    um::winuser::{GetCursorPos, GetMonitorInfoW, MonitorFromPoint, MONITORINFOEXW, MONITOR_DEFAULTTONEAREST},
};

// --- DATA STRUCTURES ---

#[derive(Clone)]
struct CaptureRequest {
    global_x: i32,
    global_y: i32,
    width: u32,
    height: u32,
}

struct FrameData {
    pixels: Vec<u8>,
    #[allow(dead_code)]  // Used for debugging
    monitor_x: i32,
    #[allow(dead_code)]  // Used for debugging
    monitor_y: i32,
    #[allow(dead_code)]  // Used for debugging
    monitor_width: u32,
    #[allow(dead_code)]  // Used for debugging
    monitor_height: u32,
    #[allow(dead_code)]  // Used for debugging
    crop_x: i32,
    #[allow(dead_code)]  // Used for debugging
    crop_y: i32,
    crop_width: u32,
    crop_height: u32,
}

// --- CAPTURE HANDLER ---

struct SingleFrameHandler {
    tx: mpsc::Sender<FrameData>,
    monitor_info: (i32, i32, u32, u32, i32, i32, u32, u32), // mx, my, mw, mh, crop_x, crop_y, crop_w, crop_h
}

impl GraphicsCaptureApiHandler for SingleFrameHandler {
    type Flags = (mpsc::Sender<FrameData>, (i32, i32, u32, u32, i32, i32, u32, u32));
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
        let (mx, my, mw, mh, crop_x, crop_y, crop_w, crop_h) = self.monitor_info;
        
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
        // Just need to ensure they're within frame bounds
        let physical_crop_x = crop_x.max(0).min(frame_width as i32 - crop_w as i32);
        let physical_crop_y = crop_y.max(0).min(frame_height as i32 - crop_h as i32);
        
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
        
        tracing::info!("Windows API: monitor at cursor is {}x{} at ({},{})", 
                      right - left, bottom - top, left, top);
        
        // Create windows-capture Monitor directly from HMONITOR handle
        let monitor = Monitor::from_raw_hmonitor(hmonitor as *mut std::ffi::c_void);
        
        let m_width = monitor.width()? as i32;
        let m_height = monitor.height()? as i32;
        
        tracing::info!("windows-capture: monitor is {}x{} (physical pixels)", m_width, m_height);
        
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
    tracing::info!("Capture request: {}x{}", width, height);
    
    // 1. Get cursor position in LOGICAL coordinates (Windows API)
    let (cursor_x_logical, cursor_y_logical) = get_cursor_position()?;
    tracing::info!("Cursor position (logical): ({}, {})", cursor_x_logical, cursor_y_logical);
    
    // 2. Get monitor at cursor with its LOGICAL bounds
    let (monitor, m_left, m_top, m_right, m_bottom) = get_monitor_at_cursor()?;
    
    // 3. Get monitor's PHYSICAL dimensions from windows-capture
    let monitor_physical_width = monitor.width()? as i32;
    let monitor_physical_height = monitor.height()? as i32;
    
    // 4. Calculate DPI scale factor (physical / logical)
    let monitor_logical_width = m_right - m_left;
    let monitor_logical_height = m_bottom - m_top;
    let scale_x = monitor_physical_width as f32 / monitor_logical_width as f32;
    let scale_y = monitor_physical_height as f32 / monitor_logical_height as f32;
    
    tracing::info!("Monitor: logical={}x{}, physical={}x{}, scale=({:.2}, {:.2})",
                  monitor_logical_width, monitor_logical_height,
                  monitor_physical_width, monitor_physical_height,
                  scale_x, scale_y);
    
    // 5. Convert cursor from logical to PHYSICAL coordinates (relative to monitor)
    let cursor_x_physical = ((cursor_x_logical - m_left) as f32 * scale_x) as i32;
    let cursor_y_physical = ((cursor_y_logical - m_top) as f32 * scale_y) as i32;
    
    tracing::info!("Cursor position (physical, relative to monitor): ({}, {})", 
                  cursor_x_physical, cursor_y_physical);
    
    // 6. Calculate capture region CENTERED on cursor (in PHYSICAL coordinates)
    let req = CaptureRequest {
        global_x: cursor_x_physical - (width as i32 / 2),  // Center on cursor!
        global_y: cursor_y_physical - (height as i32 / 2),  // Center on cursor!
        width,
        height,
    };
    
    tracing::info!("Capture region (physical): ({},{}) size {}x{}", 
                  req.global_x, req.global_y, width, height);

    // 7. Get monitor containing cursor (already have it)
    let mut relevant_monitors = Vec::new();
    
    // Check if capture region intersects with this monitor (in physical coordinates)
    let intersects = !(
        req.global_x >= monitor_physical_width ||
        req.global_x + req.width as i32 <= 0 ||
        req.global_y >= monitor_physical_height ||
        req.global_y + req.height as i32 <= 0
    );
    
    if intersects {
        relevant_monitors.push((
            monitor, 
            0,  // Physical origin is (0, 0) for this monitor
            0, 
            monitor_physical_width as u32, 
            monitor_physical_height as u32
        ));
    }

    // 8. Capture frames from monitor containing cursor
    let (tx, rx) = mpsc::channel();
    let num_monitors = relevant_monitors.len();

    // Store capture controls to keep them alive until frame is received
    let mut _capture_controls = Vec::new();

    for (monitor, mx, my, mw, mh) in relevant_monitors {
        let tx_clone = tx.clone();

        // Pass physical coordinates - no scaling needed in handler
        // Note: Use Default for border settings - Windows 10 doesn't support toggling
        let settings = Settings::new(
            monitor,
            CursorCaptureSettings::WithCursor,
            DrawBorderSettings::Default,  // Windows 10 doesn't support WithBorder/WithoutBorder
            SecondaryWindowSettings::Default,
            MinimumUpdateIntervalSettings::Default,
            DirtyRegionSettings::Default,
            ColorFormat::Bgra8,  // Windows native format
            (tx_clone, (mx, my, mw, mh, req.global_x, req.global_y, req.width, req.height)),
        );

        // Use start_free_threaded() which properly handles COM initialization
        // Returns a CaptureControl that must be kept alive during capture
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

    // 9. Stitch results (now just one cropped image)
    let mut canvas = RgbaImage::new(width, height);
    for i in 0..num_monitors {
        let frame = rx.recv()?;
        let expected_bytes = (frame.crop_width * frame.crop_height * 4) as usize;
        
        tracing::debug!(
            "Received frame #{}: {}x{} = {} pixels, data = {} bytes, expected {} bytes (BGRA format)",
            i, frame.crop_width, frame.crop_height, 
            frame.crop_width * frame.crop_height,
            frame.pixels.len(),
            expected_bytes
        );
        
        // Convert BGRA to RGBA and create image
        let mut rgba_pixels = Vec::with_capacity(frame.pixels.len());
        for bgra in frame.pixels.chunks(4) {
            if bgra.len() == 4 {
                rgba_pixels.push(bgra[2]); // R
                rgba_pixels.push(bgra[1]); // G
                rgba_pixels.push(bgra[0]); // B
                rgba_pixels.push(bgra[3]); // A
            }
        }
        
        let monitor_img = RgbaImage::from_raw(frame.crop_width, frame.crop_height, rgba_pixels)
            .ok_or_else(|| {
                format!(
                    "Failed to create image: {}x{} needs {} bytes but got {} bytes",
                    frame.crop_width, frame.crop_height,
                    expected_bytes,
                    frame.pixels.len()
                )
            })?;
        
        tracing::info!("Successfully created {}x{} image with cursor", frame.crop_width, frame.crop_height);

        // Copy pixels to canvas (frame is already cropped to requested region)
        for local_y in 0..frame.crop_height {
            for local_x in 0..frame.crop_width {
                let pixel = monitor_img.get_pixel(local_x, local_y);
                canvas.put_pixel(local_x, local_y, *pixel);
            }
        }
    }

    Ok(canvas)
}
