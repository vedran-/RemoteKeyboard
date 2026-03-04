//! Screen Capture Service
//!
//! Captures screen area around cursor for streaming to mobile client.
//! Uses CaptureManager with persistent Windows Graphics Capture sessions.

use std::sync::Mutex;
use tracing::debug;

use crate::application::ports::Result;
use crate::infrastructure::capture_manager::CaptureManager;

/// Screen capture service with persistent capture sessions
pub struct ScreenCaptureService {
    capture_manager: Mutex<CaptureManager>,
}

impl ScreenCaptureService {
    /// Create new screen capture service
    pub fn new() -> Result<Self> {
        debug!("Screen capture initialized (persistent WGC sessions)");

        Ok(ScreenCaptureService {
            capture_manager: Mutex::new(CaptureManager::new()),
        })
    }

    /// Set viewport dimensions and zoom level from client request
    pub fn set_viewport_and_zoom(&self, viewport_width: u32, viewport_height: u32, zoom_level: f32) {
        let mut manager = self.capture_manager.lock().unwrap();
        manager.update_viewport(viewport_width, viewport_height, zoom_level);
        
        let zoom_clamped = zoom_level.clamp(0.1, 5.0);
        debug!("Viewport set to {}x{}, zoom: {:.2}", viewport_width, viewport_height, zoom_clamped);
    }

    /// Capture screen area around cursor and encode as JPEG
    /// Returns None if screen hasn't changed since last capture (skip-if-unchanged)
    pub fn capture_around_cursor(&self, last_seq: u64) -> Result<Option<(Vec<u8>, u64)>> {
        let mut manager = self.capture_manager.lock().unwrap();
        manager.get_latest_jpeg(last_seq)
    }

    /// Get current viewport width
    pub fn get_viewport_width(&self) -> u32 {
        let manager = self.capture_manager.lock().unwrap();
        manager.viewport_width()
    }

    /// Get current viewport height
    pub fn get_viewport_height(&self) -> u32 {
        let manager = self.capture_manager.lock().unwrap();
        manager.viewport_height()
    }

    /// Get current zoom level
    pub fn get_zoom_level(&self) -> f32 {
        let manager = self.capture_manager.lock().unwrap();
        manager.zoom_level()
    }
}

impl Default for ScreenCaptureService {
    fn default() -> Self {
        Self::new().unwrap()
    }
}
