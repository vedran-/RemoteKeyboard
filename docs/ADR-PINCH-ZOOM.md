# ADR: Server-Side Zoom with Viewport-Based Capture

**Date:** 2026-03-03  
**Status:** Implemented  
**Deciders:** Development Team

---

## Context

The RemoteKeyboard application streams screen captures from the PC to the mobile client. The initial implementation had the client sending capture dimensions directly, which was inefficient:

- Client requested large capture (e.g., 1600x1200 for zoomed out view)
- Server captured and sent full-size image
- Client scaled down to fit viewport
- **Wasted bandwidth** sending pixels that get discarded

### Requirements

1. Client sends viewport dimensions (touchpad display area)
2. Client sends zoom level (0.1x to 5.0x)
3. Server calculates capture size: `capture = viewport × zoom`
4. Server scales captured image to viewport size before sending
5. Always send viewport-sized images (efficient bandwidth)
6. Support zoom in (>1.0x) and zoom out (<1.0x)

---

## Decision

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Mobile Client                           │
│                                                             │
│  Touchpad Viewport: 800×600                                 │
│  Zoom Level: 2.0x                                           │
│                      ↓                                      │
│  Send: { viewport_width, viewport_height, zoom_level }      │
└─────────────────────────────────────────────────────────────┘
                          ↓ WebSocket
┌─────────────────────────────────────────────────────────────┐
│                      PC Server                              │
│                                                             │
│  Calculate: capture = 800×600 × 2.0 = 1600×1200            │
│  Capture 1600×1200 area around cursor                       │
│  Scale DOWN to 800×600 (viewport size)                      │
│  Send 800×600 image                                         │
└─────────────────────────────────────────────────────────────┘
```

### Protocol Message

**Client → Server:**
```json
{
  "type": "screen_frame_request",
  "viewport_width": 800,
  "viewport_height": 600,
  "zoom_level": 2.0
}
```

**Server → Client:**
```json
{
  "type": "screen_frame",
  "cursor_x": 400,
  "cursor_y": 300,
  "monitor_id": 0,
  "capture_width": 800,
  "capture_height": 600,
  "data": "<base64 JPEG>"
}
```

### Zoom Formula

```
capture_width  = viewport_width  × zoom_level
capture_height = viewport_height × zoom_level

Server always scales capture to viewport size before sending.
```

**Examples:**

| Viewport | Zoom | Capture | Sent | Effect |
|----------|------|---------|------|--------|
| 800×600 | 1.0x | 800×600 | 800×600 | Native (1:1) |
| 800×600 | 2.0x | 1600×1200 | 800×600 | Zoomed in (more detail) |
| 800×600 | 0.5x | 400×300 | 800×600 | Zoomed out (wider view) |
| 800×600 | 4.0x | 3200×2400 | 800×600 | Maximum zoom |
| 800×600 | 0.1x | 80×60 | 800×600 | Maximum zoom out |

### Zoom Range

- **Minimum:** 0.1x (10%) - maximum zoom out, wide view
- **Maximum:** 5.0x (500%) - maximum zoom in, fine detail
- **Default:** 1.0x (100%) - native viewport size

### Server Implementation

```rust
pub struct ScreenFrameRequest {
    pub viewport_width: u32,
    pub viewport_height: u32,
    pub zoom_level: f32,
}

impl ScreenFrameRequest {
    pub fn capture_dimensions(&self) -> (u32, u32) {
        let w = (self.viewport_width as f32 * self.zoom_level) as u32;
        let h = (self.viewport_height as f32 * self.zoom_level) as u32;
        (w, h)
    }
}

// In capture service:
let (capture_w, capture_h) = request.capture_dimensions();
let image = capture_region(capture_w, capture_h);

// Scale to viewport size
if zoom_level != 1.0 {
    scale_image(image, viewport_width, viewport_height)
} else {
    image
}
```

### Client Implementation

```dart
class ScreenFrameRequest {
  final int viewportWidth;
  final int viewportHeight;
  final double zoomLevel;
  
  Map<String, dynamic> toJson() => {
    'viewport_width': viewportWidth,
    'viewport_height': viewportHeight,
    'zoom_level': zoomLevel,
  };
}

// In service:
void startStreaming({
  required int viewportWidth,
  required int viewportHeight,
  double zoomLevel = 1.0,
}) {
  _viewportWidth = viewportWidth;
  _viewportHeight = viewportHeight;
  _zoomLevel = zoomLevel.clamp(0.1, 5.0);
  _sendFrameRequest();
}

void setZoomLevel(double zoom) {
  _zoomLevel = zoom.clamp(0.1, 5.0);
  _sendFrameRequest();  // Notify server
}
```

---

## Consequences

### Positive

1. **Efficient bandwidth** - Always send viewport-sized images
2. **Server does the work** - Server has more CPU/GPU resources
3. **Clean separation** - Client declares intent, server handles implementation
4. **Flexible zoom** - 0.1x to 5.0x range works naturally
5. **Perfect aspect ratio** - Client viewport aspect ratio always preserved
6. **Cursor always centered** - Scaling preserves relative position

### Negative

1. **Server CPU usage** - Server must scale images (minimal with modern CPUs)
2. **Round-trip latency** - Zoom changes require server communication
3. **No client-side zoom buffering** - Must wait for server response

### Risks

1. **Extreme zoom out (<1.0x)** - Upscaling may look blurry
   - Mitigation: Document that <1.0x is for wide view, not detail
2. **Extreme zoom in (>4.0x)** - May capture beyond screen bounds
   - Mitigation: Server handles edge cases with padding/clamping
3. **Aspect ratio mismatch** - Client viewport differs from capture
   - Mitigation: Server scales to exact viewport size, no distortion

---

## Testing

### Server Tests
- Capture calculation: `capture = viewport × zoom`
- Scaling logic: downscale (>1x), upscale (<1x), no scale (=1x)
- Aspect ratio preservation
- Cursor centering after scale

### Client Tests (11 passing)
- Default zoom level is 1.0
- Start streaming with custom zoom level
- Zoom in/out increases/decreases zoom
- Zoom clamping (0.1x - 5.0x)
- Reset zoom functionality
- Message format verification
- Viewport dimension updates

---

## Related Documents

- [PROTOCOL.md](PROTOCOL.md) - Screen streaming protocol
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [PROGRESS.md](PROGRESS.md) - Implementation progress

---

*Last Updated: 2026-03-03*
*Version: 2.0*
