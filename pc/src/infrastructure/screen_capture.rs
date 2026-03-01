//! Screen Capture Service
//!
//! Captures screen area around cursor for streaming to mobile client.
//! Uses xcap crate for cross-platform screen capture.

use std::sync::Arc;
use std::sync::Mutex;
use xcap::Monitor;
use image::ImageFormat;
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use tracing::{debug, info, warn, error};

use crate::application::ports::{Result, Error};
use crate::domain::entities::command::ScreenFrame;

/// Default capture size (width and height in pixels)
const DEFAULT_CAPTURE_SIZE: u32 = 200;

/// Minimum capture size
const MIN_CAPTURE_SIZE: u32 = 100;

/// Maximum capture size
const MAX_CAPTURE_SIZE: u32 = 400;

/// JPEG quality (0-100)
const JPEG_QUALITY: u8 = 75;

/// Screen capture service
#[derive(Clone)]
pub struct ScreenCaptureService {
    capture_width: Arc<Mutex<u32>>,
    capture_height: Arc<Mutex<u32>>,
    max_dimension: Arc<Mutex<u32>>,  // Max dimension for downscaling
}

impl ScreenCaptureService {
    /// Create new screen capture service
    pub fn new() -> Result<Self> {
        // Test that screen capture works
        match Monitor::all() {
            Ok(monitors) => {
                info!("Screen capture initialized: {} monitor(s) available", monitors.len());
                Ok(ScreenCaptureService {
                    capture_width: Arc::new(Mutex::new(200)),
                    capture_height: Arc::new(Mutex::new(200)),
                    max_dimension: Arc::new(Mutex::new(400)),
                })
            }
            Err(e) => {
                error!("Screen capture initialization failed: {}", e);
                Err(Error::input(format!("Failed to initialize screen capture: {}", e)))
            }
        }
    }

    /// Capture screen area around cursor
    pub fn capture_around_cursor(&self) -> Result<ScreenFrame> {
        let capture_width = *self.capture_width.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;
        let capture_height = *self.capture_height.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;
        let max_dimension = *self.max_dimension.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;

        // Get cursor position (virtual screen coordinates)
        let (cursor_x, cursor_y) = match mouse_position::mouse_position::Mouse::get_mouse_position() {
            mouse_position::mouse_position::Mouse::Position { x, y } => (x, y),
            _ => (0, 0)
        };

        // Find which monitor contains cursor
        let monitors = Monitor::all().map_err(|e| {
            Error::input(format!("Failed to get monitors: {}", e))
        })?;

        let monitor = monitors.iter()
            .find(|m| {
                let mx = m.x().unwrap_or(0) as i32;
                let my = m.y().unwrap_or(0) as i32;
                let mw = m.width().unwrap_or(1920) as i32;
                let mh = m.height().unwrap_or(1080) as i32;
                let cx = cursor_x as i32;
                let cy = cursor_y as i32;
                (cx >= mx) && (cx < mx + mw) && (cy >= my) && (cy < my + mh)
            })
            .unwrap_or(&monitors[0]);

        // Calculate capture region (centered on cursor)
        let half_width = (capture_width / 2) as i32;
        let half_height = (capture_height / 2) as i32;
        let monitor_x = monitor.x().unwrap_or(0) as i32;
        let monitor_y = monitor.y().unwrap_or(0) as i32;
        let monitor_w = monitor.width().unwrap_or(1920) as i32;
        let monitor_h = monitor.height().unwrap_or(1080) as i32;
        
        let max_x = monitor_w - capture_width as i32;
        let max_y = monitor_h - capture_height as i32;
        let region_x = std::cmp::max(0, std::cmp::min(cursor_x as i32 - monitor_x - half_width, max_x));
        let region_y = std::cmp::max(0, std::cmp::min(cursor_y as i32 - monitor_y - half_height, max_y));

        // Capture region
        let image = monitor.capture_region(
            region_x as u32,
            region_y as u32,
            capture_width,
            capture_height
        ).map_err(|e| {
            Error::input(format!("Failed to capture screen: {}", e))
        })?;

        // Convert to RGB (JPEG doesn't support alpha channel)
        let rgb_image = image::DynamicImage::ImageRgba8(image).into_rgb8();
        
        // Downscale if image is too large (server-side optimization)
        let final_image = if capture_width > max_dimension || capture_height > max_dimension {
            let scale = (max_dimension as f32 / capture_width.max(capture_height) as f32);
            let new_width = (capture_width as f32 * scale) as u32;
            let new_height = (capture_height as f32 * scale) as u32;
            debug!("Downscaling capture from {}x{} to {}x{}", capture_width, capture_height, new_width, new_height);
            image::imageops::resize(&rgb_image, new_width, new_height, image::imageops::FilterType::Triangle)
        } else {
            rgb_image
        };

        // Convert to JPEG
        let mut jpeg_data = Vec::new();
        final_image.write_to(&mut std::io::Cursor::new(&mut jpeg_data), ImageFormat::Jpeg)
            .map_err(|e| {
                Error::input(format!("Failed to encode JPEG: {}", e))
            })?;

        // Encode as base64
        let base64_data = BASE64.encode(&jpeg_data);

        let final_width = final_image.width();
        let final_height = final_image.height();

        debug!(
            "Screen captured: {}x{} at ({},{}), JPEG {} bytes, base64 {} bytes",
            final_width, final_height,
            region_x, region_y,
            jpeg_data.len(),
            base64_data.len()
        );

        Ok(ScreenFrame {
            cursor_x: cursor_x as i32,
            cursor_y: cursor_y as i32,
            monitor_id: monitor.id().unwrap_or(0),
            capture_width: final_width,
            capture_height: final_height,
            data: base64_data,
        })
    }

    /// Set capture dimensions
    pub fn set_capture_dimensions(&self, width: u32, height: u32) {
        let clamped_width = width.clamp(100, 800);
        let clamped_height = height.clamp(100, 800);
        
        let mut current_width = self.capture_width.lock().unwrap();
        let mut current_height = self.capture_height.lock().unwrap();
        
        if *current_width != clamped_width || *current_height != clamped_height {
            info!("Capture dimensions changed: {}x{} -> {}x{}", 
                  *current_width, *current_height, clamped_width, clamped_height);
            *current_width = clamped_width;
            *current_height = clamped_height;
        }
    }

    /// Set max dimension for downscaling
    pub fn set_max_dimension(&self, max: u32) {
        let clamped_max = max.clamp(200, 800);
        let mut current = self.max_dimension.lock().unwrap();
        
        if *current != clamped_max {
            info!("Max dimension changed: {} -> {}", *current, clamped_max);
            *current = clamped_max;
        }
    }

    /// Get current capture width
    pub fn get_capture_width(&self) -> u32 {
        *self.capture_width.lock().unwrap()
    }

    /// Get current capture height
    pub fn get_capture_height(&self) -> u32 {
        *self.capture_height.lock().unwrap()
    }
}
