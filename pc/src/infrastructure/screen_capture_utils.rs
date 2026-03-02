//! Screen Capture Utilities - Working Version
//!
//! Uses Windows API (winapi) for cursor position + monitor bounds
//! Uses windows-capture for actual screen capture with cursor

use std::sync::mpsc;
use std::thread;
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
    monitor_x: i32,
    monitor_y: i32,
    monitor_width: u32,
    monitor_height: u32,
    crop_x: i32,
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
        
        // Crop to requested region using ACTUAL frame dimensions
        let crop_pixels = crop_image(
            &full_pixels,
            frame_width, frame_height,
            crop_x - mx, crop_y - my,  // Convert to monitor-relative coordinates
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

/// Enumerate all monitors with their bounds
fn enumerate_monitors_with_bounds() -> Result<Vec<(Monitor, i32, i32, i32, i32)>, Box<dyn std::error::Error>> {
    // For now, just return the monitor at cursor position
    // TODO: Properly enumerate all monitors if needed for multi-monitor stitching
    let (monitor, left, top, right, bottom) = get_monitor_at_cursor()?;
    Ok(vec![(monitor, left, top, right, bottom)])
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
    
    // 1. Get cursor position
    let (cursor_x, cursor_y) = get_cursor_position()?;
    tracing::info!("Cursor position: ({}, {})", cursor_x, cursor_y);
    
    let req = CaptureRequest {
        global_x: cursor_x - (width as i32 / 2),
        global_y: cursor_y - (height as i32 / 2),
        width,
        height,
    };
    
    tracing::info!("Capture region: ({},{}) size {}x{}", req.global_x, req.global_y, width, height);

    // 2. Get monitor containing cursor
    let monitors = enumerate_monitors_with_bounds()?;
    let mut relevant_monitors = Vec::new();

    for (m, m_left, m_top, m_right, m_bottom) in monitors {
        // Check for intersection
        let intersects = !(
            req.global_x >= m_right || 
            req.global_x + req.width as i32 <= m_left || 
            req.global_y >= m_bottom || 
            req.global_y + req.height as i32 <= m_top
        );

        if intersects {
            let mw = (m_right - m_left) as u32;
            let mh = (m_bottom - m_top) as u32;
            relevant_monitors.push((m, m_left, m_top, mw, mh));
        }
    }

    // 3. Capture frames from monitor containing cursor
    let (tx, rx) = mpsc::channel();
    let num_monitors = relevant_monitors.len();

    for (monitor, mx, my, mw, mh) in relevant_monitors {
        let tx_clone = tx.clone();
        
        // Pass the capture REQUEST dimensions, not monitor dimensions
        // We'll crop the captured image to the requested region
        let settings = Settings::new(
            monitor,
            CursorCaptureSettings::WithCursor,
            DrawBorderSettings::WithoutBorder,
            SecondaryWindowSettings::Default,
            MinimumUpdateIntervalSettings::Default,
            DirtyRegionSettings::Default,
            ColorFormat::Bgra8,  // Windows native format
            (tx_clone, (mx, my, mw, mh, req.global_x, req.global_y, req.width, req.height)),
        );

        std::thread::spawn(move || {
            let _ = SingleFrameHandler::start(settings);
        });
    }

    // 4. Stitch results from all monitors
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
        
        tracing::info!("Successfully created {}x{} image with cursor from monitor at ({},{})", 
                      frame.crop_width, frame.crop_height, frame.crop_x, frame.crop_y);

        // Copy pixels to canvas at correct position
        // The frame's crop region is in global virtual screen coordinates
        // We need to place it at the correct position on the canvas
        for local_y in 0..frame.crop_height {
            for local_x in 0..frame.crop_width {
                // Calculate global virtual screen position
                let global_x = frame.crop_x + local_x as i32;
                let global_y = frame.crop_y + local_y as i32;
                
                // Convert to canvas coordinates (relative to capture request)
                let canvas_x = (global_x - req.global_x) as u32;
                let canvas_y = (global_y - req.global_y) as u32;
                
                // Only draw if within canvas bounds
                if canvas_x < width && canvas_y < height {
                    let pixel = monitor_img.get_pixel(local_x, local_y);
                    canvas.put_pixel(canvas_x, canvas_y, *pixel);
                }
            }
        }
    }

    Ok(canvas)
}
