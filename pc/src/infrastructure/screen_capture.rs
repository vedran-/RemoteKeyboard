//! Screen Capture Service
//!
//! Captures screen area around cursor for streaming to mobile client.
//! Uses Windows Graphics Capture API with multi-monitor stitching support.

use std::sync::Arc;
use std::sync::Mutex;
use image::{ImageFormat, imageops};
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use tracing::{debug, info};

use crate::application::ports::{Result, Error};
use crate::domain::entities::command::ScreenFrame;
use crate::infrastructure::screen_capture_utils::get_screen_area_around_cursor;
use crate::infrastructure::config::AppConfig;

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
        // Load configuration
        let config = AppConfig::load();
        let max_dim = config.screen_capture.max_dimension;
        let default_w = config.screen_capture.default_width;
        let default_h = config.screen_capture.default_height;
        
        info!("Screen capture initialized (Windows Graphics Capture API)");
        info!("Using max_dimension={}, default capture={}x{}", 
              max_dim, default_w, default_h);
        
        Ok(ScreenCaptureService {
            capture_width: Arc::new(Mutex::new(default_w)),
            capture_height: Arc::new(Mutex::new(default_h)),
            max_dimension: Arc::new(Mutex::new(max_dim)),
        })
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

        // Capture screen area centered on cursor (with multi-monitor stitching)
        let image = get_screen_area_around_cursor(capture_width, capture_height)
            .map_err(|e| Error::input(format!("Failed to capture screen: {}", e)))?;
        
        info!("Screen captured: {}x{} with cursor", image.width(), image.height());

        // Convert RGBA to RGB (JPEG doesn't support alpha)
        let rgb_image = image::DynamicImage::ImageRgba8(image).into_rgb8();

        // Downscale if image is too large (server-side optimization)
        let final_image = if capture_width > max_dimension || capture_height > max_dimension {
            let scale = max_dimension as f32 / capture_width.max(capture_height) as f32;
            let new_width = (capture_width as f32 * scale) as u32;
            let new_height = (capture_height as f32 * scale) as u32;
            debug!("Downscaling capture from {}x{} to {}x{}", capture_width, capture_height, new_width, new_height);
            imageops::resize(&rgb_image, new_width, new_height, imageops::FilterType::Triangle)
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
            "Screen captured: {}x{}, JPEG {} bytes, base64 {} bytes",
            final_width, final_height,
            jpeg_data.len(),
            base64_data.len()
        );

        Ok(ScreenFrame {
            cursor_x: (capture_width / 2) as i32,  // Cursor is always at center
            cursor_y: (capture_height / 2) as i32,  // Cursor is always at center
            monitor_id: 0,  // Multi-monitor stitched, no single monitor ID
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
