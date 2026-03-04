//! Capture Manager
//!
//! Maintains persistent Windows Graphics Capture sessions to avoid
//! the overhead of recreating contexts (D3D11 devices/textures) for every frame.
//! This provides a massive speedup for continuous screen streaming.

use std::sync::mpsc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use image::RgbaImage;
use tracing::{debug, error, warn};
use windows_capture::{
    capture::{Context, GraphicsCaptureApiHandler},
    frame::Frame,
    graphics_capture_api::InternalCaptureControl,
    settings::{
        ColorFormat, CursorCaptureSettings, DirtyRegionSettings, DrawBorderSettings,
        MinimumUpdateIntervalSettings, SecondaryWindowSettings, Settings,
    },
};

use crate::application::ports::{Result, Error};
use crate::infrastructure::screen_capture_utils::{get_all_monitors, crop_image};

/// Frame data received from a single monitor capture
struct FrameData {
    pixels: Vec<u8>,
    monitor_width: u32,
    monitor_height: u32,
    physical_crop_x: i32,
    physical_crop_y: i32,
    crop_width: u32,
    crop_height: u32,
    canvas_offset_x: u32,
    canvas_offset_y: u32,
}

/// Persistent capture handler for a single monitor
struct PersistentFrameHandler {
    tx: mpsc::Sender<FrameData>,
    monitor_info: (u32, u32, i32, i32, u32, u32, u32, u32), // mw, mh, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y
}

impl GraphicsCaptureApiHandler for PersistentFrameHandler {
    type Flags = (mpsc::Sender<FrameData>, (u32, u32, i32, i32, u32, u32, u32, u32));
    type Error = Box<dyn std::error::Error + Send + Sync>;

    fn new(ctx: Context<Self::Flags>) -> std::result::Result<Self, Self::Error> {
        Ok(Self { 
            tx: ctx.flags.0, 
            monitor_info: ctx.flags.1 
        })
    }

    fn on_frame_arrived(
        &mut self,
        frame: &mut Frame,
        _capture_control: InternalCaptureControl
    ) -> std::result::Result<(), Self::Error> {
        let (mw, mh, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y) = self.monitor_info;

        let frame_width = frame.width();
        let frame_height = frame.height();

        let mut buffer = frame.buffer()?;
        let nopadding_buffer = buffer.as_nopadding_buffer()?;
        let full_pixels = nopadding_buffer.to_vec();

        let calc_bpp = full_pixels.len() / (frame_width * frame_height) as usize;

        let crop_pixels = crop_image(
            &full_pixels,
            frame_width, frame_height,
            crop_x, crop_y,
            crop_w, crop_h,
            calc_bpp as u32,
        );

        let _ = self.tx.send(FrameData {
            pixels: crop_pixels,
            monitor_width: mw,
            monitor_height: mh,
            physical_crop_x: crop_x,
            physical_crop_y: crop_y,
            crop_width: crop_w,
            crop_height: crop_h,
            canvas_offset_x: canvas_x,
            canvas_offset_y: canvas_y,
        });

        // DO NOT call capture_control.stop() - this is a persistent session
        Ok(())
    }

    fn on_closed(&mut self) -> std::result::Result<(), Self::Error> {
        Ok(())
    }
}

/// Active capture session with persistent WGC sessions
pub struct CaptureSession {
    // Hold controls to keep sessions alive - using opaque type
    controls: Vec<Box<dyn std::any::Any + Send>>,
    rx: mpsc::Receiver<FrameData>,
    pub num_monitors: usize,
    pub width: u32,
    pub height: u32,
    pub logical_cursor_x: i32,
    pub logical_cursor_y: i32,
}

/// Result from get_latest_jpeg - either new frame with sequence or None if unchanged
pub struct CapturedFrame {
    pub image: RgbaImage,
    pub sequence: u64,
}

/// Capture Manager - maintains persistent capture sessions
pub struct CaptureManager {
    session: Option<CaptureSession>,
    frame_seq: Arc<AtomicU64>,
    viewport_width: u32,
    viewport_height: u32,
    zoom_level: f32,
}

impl CaptureManager {
    pub fn new() -> Self {
        Self {
            session: None,
            frame_seq: Arc::new(AtomicU64::new(1)),  // Start at 1 so first capture works
            viewport_width: 400,
            viewport_height: 300,
            zoom_level: 1.0,
        }
    }

    /// Get viewport width
    pub fn viewport_width(&self) -> u32 {
        self.viewport_width
    }

    /// Get viewport height
    pub fn viewport_height(&self) -> u32 {
        self.viewport_height
    }

    /// Get zoom level
    pub fn zoom_level(&self) -> f32 {
        self.zoom_level
    }

    /// Update viewport dimensions and zoom level
    pub fn update_viewport(&mut self, width: u32, height: u32, zoom: f32) {
        self.viewport_width = width;
        self.viewport_height = height;
        self.zoom_level = zoom.clamp(0.1, 5.0);
        // Session will be recreated on next get_latest_jpeg if needed
        self.session = None;
    }

    /// Stop all capture sessions and cleanup
    pub fn stop(&mut self) {
        self.session = None;
    }

    /// Capture screen area around cursor and encode as JPEG
    /// Always captures a fresh frame - no skip logic
    pub fn get_latest_jpeg(&mut self, _last_seq: u64) -> Result<Option<(Vec<u8>, u64)>> {
        let width = self.viewport_width;
        let height = self.viewport_height;

        // Always capture fresh frame - no skip logic
        debug!("Capturing fresh frame {}x{}", width, height);

        // Get or create session
        let (num_monitors, session_width, session_height) = {
            let sess = self.get_or_create_session(width, height)?;
            (sess.num_monitors, sess.width, sess.height)
        };

        // Stitch frame
        let image = self.stitch_frame(num_monitors, session_width, session_height)?;

        debug!("Frame stitched: {}x{}", image.width(), image.height());

        // Convert RGBA to RGB for JPEG encoding (JPEG doesn't support alpha)
        let rgb_image = image::DynamicImage::ImageRgba8(image).into_rgb8();

        // Encode to JPEG
        let mut jpeg_data = Vec::new();
        rgb_image.write_to(&mut std::io::Cursor::new(&mut jpeg_data), image::ImageFormat::Jpeg)
            .map_err(|e| Error::internal(format!("Failed to encode JPEG: {}", e)))?;

        // Get NEW sequence number after capture
        let new_seq = self.frame_seq.fetch_add(1, Ordering::SeqCst) + 1;

        debug!("Frame captured: {} bytes, seq={}", jpeg_data.len(), new_seq);
        Ok(Some((jpeg_data, new_seq)))
    }

    /// Get or create capture session based on cursor position
    fn get_or_create_session(
        &mut self,
        width: u32,
        height: u32,
    ) -> Result<&mut CaptureSession> {
        // Find cursor position
        let (cursor_logical_x, cursor_logical_y) = crate::infrastructure::screen_capture_utils::get_cursor_position()
            .map_err(|e| Error::internal(format!("Failed to get cursor: {}", e)))?;

        let needs_recreate = match &self.session {
            None => true,
            Some(sess) => {
                // Recreate if cursor moved significantly or viewport changed
                let dx = (sess.logical_cursor_x - cursor_logical_x).abs();
                let dy = (sess.logical_cursor_y - cursor_logical_y).abs();
                // Heuristic: Recreate if cursor jumped more than half the viewport
                dx > (width / 2) as i32 || dy > (height / 2) as i32 
                    || sess.width != width || sess.height != height
            }
        };

        if needs_recreate {
            tracing::debug!("Creating new persistent capture session at ({},{}) for {}x{}", 
                           cursor_logical_x, cursor_logical_y, width, height);
            let new_sess = Self::create_session(cursor_logical_x, cursor_logical_y, width, height)?;
            self.session = Some(new_sess);
        }

        Ok(self.session.as_mut().unwrap())
    }

    /// Create new capture session for all relevant monitors
    fn create_session(
        cursor_logical_x: i32,
        cursor_logical_y: i32,
        width: u32,
        height: u32,
    ) -> Result<CaptureSession> {
        let all_monitors = get_all_monitors()
            .map_err(|e| Error::internal(format!("Failed to get monitors: {}", e)))?;

        // Find cursor's monitor for scale reference
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

        // Convert cursor to physical coordinates for capture region calculation
        let cursor_phys_x = (cursor_logical_x as f32 * cursor_scale_x) as i32;
        let cursor_phys_y = (cursor_logical_y as f32 * cursor_scale_y) as i32;
        
        // Define capture region in physical coordinates (centered on cursor)
        let capture_left_phys = cursor_phys_x - (width as i32 / 2);
        let capture_top_phys = cursor_phys_y - (height as i32 / 2);
        let capture_right_phys = capture_left_phys + width as i32;
        let capture_bottom_phys = capture_top_phys + height as i32;

        // Find all monitors that intersect with capture region
        let mut relevant_monitors = Vec::new();

        for (monitor, m_left_logical, m_top_logical, m_right_logical, m_bottom_logical) in all_monitors {
            let monitor_logical_width = m_right_logical - m_left_logical;
            let monitor_logical_height = m_bottom_logical - m_top_logical;
            let monitor_physical_width = monitor.width()
                .map_err(|e| Error::internal(format!("Failed width: {}", e)))? as i32;
            let monitor_physical_height = monitor.height()
                .map_err(|e| Error::internal(format!("Failed height: {}", e)))? as i32;
            
            let scale_x = monitor_physical_width as f32 / monitor_logical_width as f32;
            let scale_y = monitor_physical_height as f32 / monitor_logical_height as f32;
            
            // Monitor's physical bounds (each monitor has its own physical space)
            let monitor_phys_left = (m_left_logical as f32 * scale_x) as i32;
            let monitor_phys_top = (m_top_logical as f32 * scale_y) as i32;
            let monitor_phys_right = monitor_phys_left + monitor_physical_width;
            let monitor_phys_bottom = monitor_phys_top + monitor_physical_height;

            // Check intersection with capture region
            let intersects = !(
                capture_right_phys <= monitor_phys_left ||  
                capture_left_phys >= monitor_phys_right ||   
                capture_bottom_phys <= monitor_phys_top ||   
                capture_top_phys >= monitor_phys_bottom      
            );

            if intersects {
                // Calculate overlap in physical coordinates
                let overlap_left = capture_left_phys.max(monitor_phys_left);
                let overlap_top = capture_top_phys.max(monitor_phys_top);
                let overlap_right = capture_right_phys.min(monitor_phys_right);
                let overlap_bottom = capture_bottom_phys.min(monitor_phys_bottom);
                
                // Crop region relative to this monitor's origin
                let physical_crop_x = overlap_left - monitor_phys_left;
                let physical_crop_y = overlap_top - monitor_phys_top;
                let physical_crop_w = (overlap_right - overlap_left) as u32;
                let physical_crop_h = (overlap_bottom - overlap_top) as u32;
                
                // Canvas position in output image coordinates
                let canvas_x = ((overlap_left - capture_left_phys) as f32).round().max(0.0) as u32;
                let canvas_y = ((overlap_top - capture_top_phys) as f32).round().max(0.0) as u32;
                
                relevant_monitors.push((
                    monitor,
                    physical_crop_x,
                    physical_crop_y,
                    physical_crop_w,
                    physical_crop_h,
                    canvas_x,
                    canvas_y,
                ));
            }
        }

        // Create channel for receiving frames
        let (tx, rx) = mpsc::channel();
        let num_monitors = relevant_monitors.len();
        let mut controls: Vec<Box<dyn std::any::Any + Send>> = Vec::new();

        // Start persistent capture for each relevant monitor
        for (monitor, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y) in relevant_monitors {
            let tx_clone = tx.clone();

            let mw = monitor.width().unwrap() as u32;
            let mh = monitor.height().unwrap() as u32;

            let settings = Settings::new(
                monitor,
                CursorCaptureSettings::WithCursor,
                DrawBorderSettings::Default,
                SecondaryWindowSettings::Default,
                MinimumUpdateIntervalSettings::Default,
                DirtyRegionSettings::Default,
                ColorFormat::Bgra8,
                (tx_clone, (
                    mw, mh, crop_x, crop_y, crop_w, crop_h, canvas_x, canvas_y
                )),
            );

            match PersistentFrameHandler::start_free_threaded(settings) {
                Ok(capture_control) => {
                    // Coerce to trait object
                    let boxed: Box<dyn std::any::Any + Send> = Box::new(capture_control);
                    controls.push(boxed);
                }
                Err(e) => {
                    return Err(Error::internal(format!("Failed to start persistent screen capture: {}", e)));
                }
            }
        }

        Ok(CaptureSession {
            controls,
            rx,
            num_monitors,
            width,
            height,
            logical_cursor_x: cursor_logical_x,
            logical_cursor_y: cursor_logical_y,
        })
    }

    /// Stitch frames from all monitors into a single image
    fn stitch_frame(&mut self, num_monitors: usize, width: u32, height: u32) -> Result<RgbaImage> {
        // Get session reference to access rx
        let sess = self.session.as_mut()
            .ok_or_else(|| Error::internal("No capture session"))?;
        
        debug!("stitch_frame: waiting for {} frames from {} monitors", num_monitors, sess.num_monitors);
        
        let mut canvas = RgbaImage::new(width, height);

        // Fill canvas with black first
        for y in 0..height {
            for x in 0..width {
                canvas.put_pixel(x, y, image::Rgba([0, 0, 0, 255]));
            }
        }

        // Collect frames from all monitors
        let timeout = Duration::from_millis(50);

        for i in 0..num_monitors {
            debug!("Waiting for frame {}/{}...", i + 1, num_monitors);
            let frame = sess.rx.recv_timeout(timeout).map_err(|e| {
                Error::internal(format!("Timeout waiting for capture frame #{}: {}", i + 1, e))
            })?;
            debug!("Received frame {}/{}: {}x{} pixels", i + 1, num_monitors, frame.crop_width, frame.crop_height);

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
                    Error::internal("Failed to create RgbaImage from raw frame data".to_string())
                })?;

            // Resize if needed (for DPI scaling)
            let logical_crop_w = frame.crop_width;
            let logical_crop_h = frame.crop_height;
            
            let monitor_img = if logical_crop_w != frame.crop_width || logical_crop_h != frame.crop_height {
                image::imageops::resize(
                    &physical_img,
                    logical_crop_w,
                    logical_crop_h,
                    image::imageops::Triangle,
                )
            } else {
                physical_img
            };
            
            // Copy to canvas at correct position
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

        // Increment sequence counter for new frame
        self.frame_seq.fetch_add(1, Ordering::SeqCst);

        Ok(canvas)
    }
}

impl Default for CaptureManager {
    fn default() -> Self {
        Self::new()
    }
}
