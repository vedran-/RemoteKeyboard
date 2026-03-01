//! Mouse Clamping Tests
//!
//! Tests for the multi-monitor mouse movement clamping workaround.

use crate::infrastructure::input::enigo_adapter::MAX_MOUSE_DELTA;

#[test]
fn test_max_mouse_delta_constant() {
    // Verify the clamping constant is set to a reasonable value
    // Too low: cursor movement feels sluggish
    // Too high: may trigger edge-wrapping bug
    assert!(MAX_MOUSE_DELTA > 0, "MAX_MOUSE_DELTA must be positive");
    assert!(MAX_MOUSE_DELTA <= 50, "MAX_MOUSE_DELTA should be <= 50 for smooth movement");
}

#[test]
fn test_mouse_move_within_limits_not_clamped() {
    // Mouse moves within limits should not be clamped
    let dx = 10i32;
    let dy = -5i32;
    
    let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    
    assert_eq!(clamped_dx, dx, "Small dx should not be clamped");
    assert_eq!(clamped_dy, dy, "Small dy should not be clamped");
}

#[test]
fn test_mouse_move_positive_exceeding_limits_clamped() {
    // Positive moves exceeding limit should be clamped
    let dx = 100i32;
    let dy = 50i32;
    
    let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    
    assert_eq!(clamped_dx, MAX_MOUSE_DELTA, "Large positive dx should be clamped to MAX");
    assert_eq!(clamped_dy, MAX_MOUSE_DELTA, "Large positive dy should be clamped to MAX");
}

#[test]
fn test_mouse_move_negative_exceeding_limits_clamped() {
    // Negative moves exceeding limit should be clamped
    let dx = -100i32;
    let dy = -50i32;
    
    let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    
    assert_eq!(clamped_dx, -MAX_MOUSE_DELTA, "Large negative dx should be clamped to -MAX");
    assert_eq!(clamped_dy, -MAX_MOUSE_DELTA, "Large negative dy should be clamped to -MAX");
}

#[test]
fn test_mouse_move_at_exact_limits_not_clamped() {
    // Moves at exact limits should not be clamped
    let dx = MAX_MOUSE_DELTA;
    let dy = -MAX_MOUSE_DELTA;
    
    let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    
    assert_eq!(clamped_dx, dx, "dx at MAX should not be clamped");
    assert_eq!(clamped_dy, dy, "dy at -MAX should not be clamped");
}

#[test]
fn test_clamping_preserves_zero_movement() {
    // Zero movement should remain zero
    let dx = 0i32;
    let dy = 0i32;
    
    let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
    
    assert_eq!(clamped_dx, 0, "Zero dx should remain zero");
    assert_eq!(clamped_dy, 0, "Zero dy should remain zero");
}

#[test]
fn test_clamping_allows_smooth_multi_monitor_transition() {
    // Simulate cursor moving across monitor boundary
    // Each move should be smooth and controlled
    
    let mut total_dx = 0i32;
    let mut total_dy = 0i32;
    
    // Simulate 10 large moves that would trigger the bug without clamping
    for _ in 0..10 {
        let dx = 100i32; // Would cause edge-wrapping bug
        let dy = 0i32;
        
        let clamped_dx = dx.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
        let clamped_dy = dy.clamp(-MAX_MOUSE_DELTA, MAX_MOUSE_DELTA);
        
        total_dx += clamped_dx;
        total_dy += clamped_dy;
    }
    
    // Total movement should be controlled and predictable
    assert_eq!(total_dx, MAX_MOUSE_DELTA * 10, "Total movement should be sum of clamped moves");
    assert_eq!(total_dy, 0, "No vertical movement");
}
