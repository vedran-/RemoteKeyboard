//! Screen Capture Service
//!
//! Captures screen area around cursor for streaming to mobile client.
//! Uses Windows Graphics Capture API with multi-monitor stitching support.

use std::sync::Arc;
use std::sync::Mutex;
use image::{ImageFormat, imageops};
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use tracing::{debug};

use crate::application::ports::{Result, Error};
use crate::domain::entities::command::ScreenFrame;
use crate::infrastructure::screen_capture_utils::get_screen_area_around_cursor;

/// Screen capture service
#[derive(Clone)]
pub struct ScreenCaptureService {
    viewport_width: Arc<Mutex<u32>>,
    viewport_height: Arc<Mutex<u32>>,
    zoom_level: Arc<Mutex<f32>>,
}

impl ScreenCaptureService {
    /// Create new screen capture service
    pub fn new() -> Result<Self> {
        // Default values (will be overridden by client request)
        debug!("Screen capture initialized (Windows Graphics Capture API)");

        Ok(ScreenCaptureService {
            viewport_width: Arc::new(Mutex::new(400)),
            viewport_height: Arc::new(Mutex::new(300)),
            zoom_level: Arc::new(Mutex::new(1.0)),
        })
    }

    /// Set viewport dimensions and zoom level from client request
    pub fn set_viewport_and_zoom(&self, viewport_width: u32, viewport_height: u32, zoom_level: f32) {
        *self.viewport_width.lock().unwrap() = viewport_width;
        *self.viewport_height.lock().unwrap() = viewport_height;
        *self.zoom_level.lock().unwrap() = zoom_level.clamp(0.1, 5.0);
        
        let (capture_w, capture_h) = self.capture_dimensions();
        debug!("Viewport set to {}x{}, zoom: {:.2}, capture: {}x{}", 
               viewport_width, viewport_height, zoom_level, capture_w, capture_h);
    }

    /// Calculate capture dimensions from viewport and zoom
    fn capture_dimensions(&self) -> (u32, u32) {
        let viewport_width = *self.viewport_width.lock().unwrap();
        let viewport_height = *self.viewport_height.lock().unwrap();
        let zoom_level = *self.zoom_level.lock().unwrap();
        
        let capture_width = (viewport_width as f32 * zoom_level) as u32;
        let capture_height = (viewport_height as f32 * zoom_level) as u32;
        (capture_width, capture_height)
    }

    /// Capture screen area around cursor
    pub fn capture_around_cursor(&self) -> Result<ScreenFrame> {
        let viewport_width = *self.viewport_width.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;
        let viewport_height = *self.viewport_height.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;
        let zoom_level = *self.zoom_level.lock().map_err(|e| {
            Error::internal(format!("Mutex poisoned: {}", e))
        })?;

        // Calculate capture dimensions (viewport * zoom)
        let (capture_width, capture_height) = self.capture_dimensions();

        // Capture screen area centered on cursor (with multi-monitor stitching)
        let image = get_screen_area_around_cursor(capture_width, capture_height)
            .map_err(|e| Error::input(format!("Failed to capture screen: {}", e)))?;

        // Convert RGBA to RGB (JPEG doesn't support alpha)
        let rgb_image = image::DynamicImage::ImageRgba8(image).into_rgb8();

        // Scale to viewport size (always send viewport-sized images)
        let final_image = if zoom_level != 1.0 {
            debug!("Scaling capture from {}x{} to viewport {}x{}", 
                   capture_width, capture_height, viewport_width, viewport_height);
            imageops::resize(&rgb_image, viewport_width, viewport_height, imageops::FilterType::Triangle)
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
            "Screen captured: {}x{}, JPEG {} bytes, base64 {} bytes (zoom: {:.2})",
            final_width, final_height,
            jpeg_data.len(),
            base64_data.len(),
            zoom_level
        );

        Ok(ScreenFrame {
            cursor_x: (viewport_width / 2) as i32,  // Cursor is always at center of viewport
            cursor_y: (viewport_height / 2) as i32,  // Cursor is always at center of viewport
            monitor_id: 0,  // Multi-monitor stitched, no single monitor ID
            capture_width: final_width,
            capture_height: final_height,
            data: base64_data,
        })
    }

    /// Get current viewport width
    pub fn get_viewport_width(&self) -> u32 {
        *self.viewport_width.lock().unwrap()
    }

    /// Get current viewport height
    pub fn get_viewport_height(&self) -> u32 {
        *self.viewport_height.lock().unwrap()
    }

    /// Get current zoom level
    pub fn get_zoom_level(&self) -> f32 {
        *self.zoom_level.lock().unwrap()
    }
}
