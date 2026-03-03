# ADR: Pinch Zoom for Screen Streaming

**Date:** 2026-03-03  
**Status:** Implemented  
**Deciders:** Development Team

---

## Context

The RemoteKeyboard application streams screen captures from the PC to the mobile client. Users may want to zoom in or out to see more detail or a wider area of their PC screen.

### Requirements

1. Users should be able to pinch-to-zoom on the mobile touchpad screen
2. Zoom should affect the screenshot size requested from the server
3. Higher zoom = smaller capture area (zoomed in, more detail)
4. Lower zoom = larger capture area (zoomed out, wider view)
5. Zoom level should be visible to the user
6. Zoom should be resettable to 100%
7. Mouse wheel should also control zoom (for Windows client)

---

## Decision

### Architecture

Zoom is implemented **entirely on the client side** by adjusting the capture dimensions sent to the server:

```
┌─────────────────────────────────────────────────────────────┐
│                     Mobile Client                           │
│                                                             │
│  User input (pinch/wheel) → Zoom Level (0.5x - 3.0x)       │
│                      ↓                                      │
│  Calculate: capture_size = base_size / zoom_level          │
│                      ↓                                      │
│  Send to Server: { capture_width, capture_height }          │
└─────────────────────────────────────────────────────────────┘
                          ↓ WebSocket
┌─────────────────────────────────────────────────────────────┐
│                      PC Server                              │
│                                                             │
│  Receives: capture_width, capture_height                    │
│  Captures screen area of requested size                     │
│  Streams back to mobile                                     │
└─────────────────────────────────────────────────────────────┘
```

### Zoom Formula

```
actual_capture_width  = base_width  / zoom_level
actual_capture_height = base_height / zoom_level
```

**Examples:**
- At 1.0x zoom with 400x300 base: requests 400x300 capture
- At 2.0x zoom with 400x300 base: requests 200x150 capture (zoomed in)
- At 0.5x zoom with 400x300 base: requests 800x600 capture (zoomed out)

### Zoom Range

- **Minimum:** 0.5x (50%) - shows 2x more area
- **Maximum:** 3.0x (300%) - shows 1/3 the area, more detail
- **Default:** 1.0x (100%) - normal view

### Input Methods

#### 1. Pinch Gesture (Mobile/Touch)

- **Pinch out** (spread two fingers) → Zoom in
- **Pinch in** (bring two fingers together) → Zoom out
- Gesture uses `ScaleUpdateDetails.scale` for continuous zoom

#### 2. Mouse Wheel (Windows/Desktop)

- **Scroll up** (negative delta) → Zoom in (0.1x step)
- **Scroll down** (positive delta) → Zoom out (0.1x step)
- Uses `Listener.onPointerSignal` with `PointerScrollEvent`

### Protocol

**No protocol changes required.** The existing `ScreenControl` message already supports `capture_width` and `capture_height` fields:

```json
{
  "type": "custom",
  "payload": {
    "enabled": true,
    "capture_width": 200,
    "capture_height": 150,
    "max_dimension": 400
  }
}
```

The zoom level is **internal to the client** and not transmitted to the server.

### UI Components

1. **Pinch Gesture Detector** - Captures pinch gestures on the touchpad area
2. **Mouse Wheel Listener** - Captures scroll wheel events for zoom
3. **Zoom Indicator** - Shows current zoom percentage in app bar (tap to reset)
4. **Visual Feedback** - Toast notification shows zoom level on change

### Implementation Details

#### ScreenStreamService

```dart
// Internal state
int _baseCaptureWidth = 400;    // Base dimensions at 1.0x
int _baseCaptureHeight = 300;
double _zoomLevel = 1.0;

// Calculated dimensions (sent to server)
int get captureWidth => (_baseCaptureWidth / _zoomLevel).round().clamp(100, 1920);
int get captureHeight => (_baseCaptureHeight / _zoomLevel).round().clamp(100, 1080);

// Zoom control methods
void setZoomLevel(double zoom, {bool notifyServer = true})
void resetZoom()
void zoomIn({double step = 0.25})  // Pinch uses 0.25, wheel uses 0.1
void zoomOut({double step = 0.25})
```

#### TouchpadScreen - Mouse Wheel

```dart
Listener(
  onPointerSignal: (event) {
    if (!isStreaming) return;
    
    if (event is PointerScrollEvent) {
      final scrollDelta = event.scrollDelta.dy;
      
      // Scroll up (negative) = zoom in
      if (scrollDelta < 0) {
        widget.screenStreamService.zoomIn(step: 0.1);
      } 
      // Scroll down (positive) = zoom out
      else if (scrollDelta > 0) {
        widget.screenStreamService.zoomOut(step: 0.1);
      }
      
      // Show zoom feedback
      final newZoom = widget.screenStreamService.zoomLevel;
      widget.notificationService.info(
        context, 
        'Zoom: ${(newZoom * 100).toInt()}%',
      );
    }
  },
  child: GestureDetector(...),
)
```

#### TouchpadScreen - Unified Gesture Handling

**Note:** We use only `ScaleGestureRecognizer` (via `onScaleStart/Update/End`) because it's a superset of pan gestures. Having both would be redundant and cause conflicts.

```dart
// Store last focal point for pan delta calculation
Offset _lastFocalPoint = Offset.zero;

void _handleScaleStart(ScaleStartDetails details) {
  _initialZoom = _currentZoom;
  _lastFocalPoint = details.focalPoint;
}

void _handleScaleUpdate(ScaleUpdateDetails details) {
  if (!isStreaming) return;
  
  // Multi-touch (pointerCount > 1) = pinch zoom
  if (details.pointerCount > 1) {
    final newZoom = (_initialZoom * details.scale).clamp(0.5, 3.0);
    widget.screenStreamService.setZoomLevel(newZoom, notifyServer: false);
  } 
  // Single touch (pointerCount == 1) = pan for mouse control
  else {
    final delta = details.focalPoint - _lastFocalPoint;
    _lastFocalPoint = details.focalPoint;
    
    final dx = (delta.dx * sensitivity).round();
    final dy = (delta.dy * sensitivity).round();
    
    widget.commandService.sendMouseMove(dx, dy);
  }
}

void _handleScaleEnd(ScaleEndDetails details) {
  // Only handle zoom end for multi-touch
  if (details.pointerCount > 1 && isStreaming) {
    final roundedZoom = ((_currentZoom * 4).round() / 4).clamp(0.5, 3.0);
    widget.screenStreamService.setZoomLevel(roundedZoom, notifyServer: true);
  }
}
```

```dart
// In build method - use only Scale gestures, not both pan and scale
GestureDetector(
  onScaleStart: _handleScaleStart,
  onScaleUpdate: _handleScaleUpdate,
  onScaleEnd: _handleScaleEnd,
  onTap: _handleTap,
  onSecondaryTap: _handleSecondaryTap,
  child: touchpadContainer,
)
```

---

## Consequences

### Positive

1. **No server changes required** - Uses existing protocol
2. **Smooth user experience** - Pinch gesture is intuitive
3. **Visual feedback** - Users see current zoom level
4. **Flexible** - Works with any screen size
5. **Testable** - Zoom logic is isolated and testable

### Negative

1. **Server round-trip** - Zoom changes require server communication
2. **Latency** - Zoom changes may have slight delay depending on network
3. **Bandwidth** - Higher zoom (smaller captures) uses less bandwidth, lower zoom uses more

### Risks

1. **Extreme zoom values** - Mitigated by clamping to 0.5x - 3.0x range
2. **Capture size limits** - Mitigated by clamping to 100-1920px width, 100-1080px height
3. **Aspect ratio changes** - Zoom preserves aspect ratio of base dimensions

---

## Testing

### Unit Tests (11 tests passing)

- Default zoom level is 1.0
- Start streaming with custom zoom level
- Zoom in reduces capture dimensions
- Zoom out increases capture dimensions
- setZoomLevel with notifyServer=false
- resetZoom returns to 1.0 and restores base dimensions
- Zoom level clamping (0.5 to 3.0)
- Capture dimensions clamping (100px minimum)
- Zoom control message format
- setCaptureDimensions updates base dimensions
- setCaptureDimensions with zoom applies scaling

### Manual Testing

1. Start screen streaming
2. Pinch out to zoom in - verify image shows smaller area with more detail
3. Pinch in to zoom out - verify image shows larger area
4. Tap zoom indicator - verify reset to 100%
5. Verify zoom percentage display updates correctly

---

## Future Enhancements

1. **Zoom presets** - Quick buttons for 50%, 100%, 200%
2. **Zoom animation** - Smooth transitions between zoom levels
3. **Zoom memory** - Remember last zoom level per PC
4. **Double-tap zoom** - Double-tap to toggle between 100% and 200%
5. **Keyboard shortcuts** - Ctrl+/- to zoom on Windows client

---

## Related Documents

- [PROTOCOL.md](PROTOCOL.md) - Screen control messages
- [ARCHITECTURE.md](ARCHITECTURE.md) - Service layer design
- [SPECIFICATION.md](SPECIFICATION.md) - Screen streaming requirements
