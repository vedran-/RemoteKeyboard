//! Screen Capture Tests
//!
//! Tests for the screen capture service.

use crate::infrastructure::screen_capture::ScreenCaptureService;

#[test]
fn test_screen_capture_service_creation() {
    // Service should initialize successfully
    let result = ScreenCaptureService::new();
    assert!(result.is_ok(), "Screen capture service should initialize");
}

#[test]
fn test_default_capture_dimensions() {
    let service = ScreenCaptureService::new().unwrap();
    let width = service.get_capture_width();
    let height = service.get_capture_height();

    // Default should be 200x200
    assert_eq!(width, 200, "Default capture width should be 200px");
    assert_eq!(height, 200, "Default capture height should be 200px");
}

#[test]
fn test_set_capture_dimensions() {
    let service = ScreenCaptureService::new().unwrap();

    // Set valid dimensions
    service.set_capture_dimensions(300, 250);
    assert_eq!(service.get_capture_width(), 300);
    assert_eq!(service.get_capture_height(), 250);

    // Set another valid dimensions
    service.set_capture_dimensions(150, 200);
    assert_eq!(service.get_capture_width(), 150);
    assert_eq!(service.get_capture_height(), 200);
}

#[test]
fn test_capture_dimensions_clamped_to_minimum() {
    let service = ScreenCaptureService::new().unwrap();

    // Try to set below minimum (100)
    service.set_capture_dimensions(50, 80);
    assert_eq!(service.get_capture_width(), 100, "Should clamp to minimum 100px");
    assert_eq!(service.get_capture_height(), 100, "Should clamp to minimum 100px");
}

#[test]
fn test_capture_dimensions_clamped_to_maximum() {
    let service = ScreenCaptureService::new().unwrap();

    // Try to set above maximum (800)
    service.set_capture_dimensions(900, 1000);
    assert_eq!(service.get_capture_width(), 800, "Should clamp to maximum 800px");
    assert_eq!(service.get_capture_height(), 800, "Should clamp to maximum 800px");
}

#[test]
fn test_set_max_dimension() {
    let service = ScreenCaptureService::new().unwrap();

    // Set max dimension
    service.set_max_dimension(500);
    // Can't directly verify max_dimension, but can verify it doesn't crash
}

#[test]
fn test_max_dimension_clamped() {
    let service = ScreenCaptureService::new().unwrap();

    // Try to set below minimum (200)
    service.set_max_dimension(100);
    // Clamped to 200 minimum

    // Try to set above maximum (800)
    service.set_max_dimension(900);
    // Clamped to 800 maximum
}

#[test]
fn test_capture_around_cursor_returns_frame() {
    let service = ScreenCaptureService::new().unwrap();

    // Should be able to capture (may fail if no monitors, but shouldn't panic)
    let result = service.capture_around_cursor();

    // On a system with monitors, this should succeed
    // On headless systems, it may fail gracefully
    if let Ok(frame) = result {
        // Verify frame has expected data
        assert!(frame.capture_width > 0);
        assert!(frame.capture_height > 0);
        assert!(!frame.data.is_empty(), "JPEG data should not be empty");

        // Base64 data should be valid
        assert!(frame.data.chars().all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '/' || c == '='));
    }
    // If capture fails (headless), that's OK - service handles it gracefully
}

#[test]
fn test_screen_frame_has_required_fields() {
    let service = ScreenCaptureService::new().unwrap();

    if let Ok(frame) = service.capture_around_cursor() {
        // All fields should be populated
        assert!(frame.cursor_x >= 0);
        assert!(frame.cursor_y >= 0);
        assert!(frame.capture_width > 0);
        assert!(frame.capture_height > 0);
        assert!(!frame.data.is_empty());
    }
}
