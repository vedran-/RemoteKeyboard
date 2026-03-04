# RemoteKeyboard — Protocol Redesign & Optimization Plan

## Overview

Redesign the protocol from scratch and optimize the screen capture pipeline. No backwards compatibility required.

---

## 1. New Protocol

### Client → Server (JSON text WebSocket frames)

```json
{ "type": "mouse-move", "dx": 10, "dy": -5 }
{ "type": "mouse-click", "button": "left", "state": "press" }
{ "type": "mouse-scroll", "dx": 0, "dy": 120 }
{ "type": "key-press", "key": "A" }
{ "type": "type-text", "text": "Hello World" }
{ "type": "media-key", "key": "play_pause" }
{ "type": "stream-start", "width": 800, "height": 633, "zoom": 1.3 }
{ "type": "stream-update", "width": 800, "height": 633, "zoom": 2.0 }
{ "type": "stream-stop" }
```

### Server → Client

- **Screen frames**: Binary WebSocket frames — raw JPEG bytes. JPEG contains w/h internally.
- **Control messages**: JSON text:
```json
{ "type": "connected", "session": "uuid" }
{ "type": "error", "code": "...", "message": "..." }
```

### Heartbeat

WebSocket-level ping/pong (RFC 6455). Server sends `Ping` every 5s, detects dead client if no `Pong` within 15s. No custom heartbeat messages.

### Streaming Lifecycle

- Client sends `stream-stop` on: stop button, navigate away from touchpad, app background.
- Client sends `stream-start` on: return to touchpad (if was streaming), app foreground.
- Server detects dead client via ping/pong timeout.

---

## 2. Image Format & Incremental Frames

**JPEG** confirmed best (WebP 2-3x slower encode; H.264 overkill).

**Skip-if-unchanged**: `windows-capture` fires [on_frame_arrived](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture_utils.rs#160-223) only on screen changes. Track via sequence counter, skip encode/send when unchanged.

---

## 3. Monitor Enumeration & DPI Scaling — Deep Analysis

### The Two Problems (often confused)

**Problem A: Enumeration** — Finding which monitors exist. The 20×20 grid scan calls `MonitorFromPoint()` 400 times. `EnumDisplayMonitors(NULL, NULL, callback, lparam)` does the same in 1 call. Both return identical data: `HMONITOR` + logical `RECT`.

> [!IMPORTANT]
> `EnumDisplayMonitors` was likely abandoned NOT because of DPI issues in enumeration, but because the previous LLM mixed up this fix with Problem B below and broke things.

**Problem B: DPI-aware coordinate stitching** — The REAL hard part. The current stitching code (lines 354-447) has a conceptual bug with mixed-DPI setups. Here's why:

#### The Bug

The code tries to create a "global physical coordinate space" by multiplying each monitor's logical origin by that monitor's DPI scale:

```rust
// Line 388-389 — THIS IS WRONG for mixed DPI:
let monitor_phys_left = (m_left_logical as f32 * scale_x) as i32;
let monitor_phys_top = (m_top_logical as f32 * scale_y) as i32;
```

Example of what goes wrong:
```
Monitor A: logical (0,0)-(1920,1080), physical 3840×2160, scale=2.0
Monitor B: logical (1920,0)-(3840,1080), physical 1920×1080, scale=1.0

Code computes:
Monitor A phys: (0*2, 0*2)-(0+3840, 0+2160) = (0,0)-(3840,2160)
Monitor B phys: (1920*1, 0*1)-(1920+1920, 0+1080) = (1920,0)-(3840,1080)

→ They OVERLAP from x=1920 to x=3840! Stitching breaks.
```

There is no such thing as a unified "global physical coordinate space" across monitors with different DPI scales. Each monitor's physical space is independent.

#### The Correct Algorithm

**Work entirely in LOGICAL coordinates for layout, then handle physical pixels per-monitor:**

```
1. Cursor position (logical): from GetCursorPos()
2. Capture region (logical): centered on cursor
     capture_left = cursor_x - (width / (2 * cursor_scale))
     capture_right = cursor_x + (width / (2 * cursor_scale))
   This calculates how many LOGICAL pixels correspond to `width` output pixels

3. For each monitor, compute overlap in LOGICAL coordinates:
     overlap_left = max(capture_left, monitor_left)
     overlap_right = min(capture_right, monitor_right)
     (if no overlap, skip)

4. Convert overlap to PHYSICAL crop coordinates for this specific monitor:
     crop_x = (overlap_left - monitor_left) * monitor_scale_x
     crop_y = (overlap_top - monitor_top) * monitor_scale_y
     crop_w = overlap_width * monitor_scale_x
     crop_h = overlap_height * monitor_scale_y

5. Canvas position (output pixels):
     canvas_x = (overlap_left - capture_left) * cursor_scale_x
     canvas_y = (overlap_top - capture_top) * cursor_scale_y
     canvas_w = overlap_width * cursor_scale_x  // stretched/shrunk to cursor's DPI
     canvas_h = overlap_height * cursor_scale_y

6. Crop from monitor's physical frame → resize to canvas_w × canvas_h → paste at (canvas_x, canvas_y)
```

This works because:
- Layout math stays in logical coordinates (defined by Windows, always consistent)
- Physical crops are relative to each monitor's own origin
- Canvas positions use the cursor's monitor scale as reference
- If a neighboring monitor has different DPI, its contribution gets scaled to match

#### The Fix

1. **Replace grid scan with `EnumDisplayMonitors`** — safe, returns same data, 1 call instead of 400.
2. **Rewrite coordinate math** — use the logical-first algorithm above.
3. **Cache** — call `EnumDisplayMonitors` once in `CaptureManager::new()`, re-enumerate only on capture failure.

> [!WARNING]
> The current code "works" for same-DPI setups because `scale_x` is the same for all monitors, making the "global physical" trick produce correct results. It only breaks with mixed DPI. If we're keeping same-DPI as a requirement, the existing math is fine. But the correct algorithm is not much more complex.

---

## Detailed Implementation Checklist

### Phase 1: Server Protocol Rewrite

#### 1.1 — New message types in `command.rs`

**File**: [command.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/domain/entities/command.rs)

Replace [Command](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart#177-195), `ProtocolMessage`, `MessageType`, `ScreenControl`, `ScreenFrameRequest`, [ScreenFrame](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart#170-219) with:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ClientMessage {
    #[serde(rename = "mouse-move")]
    MouseMove { dx: i32, dy: i32 },
    #[serde(rename = "mouse-click")]
    MouseClick { button: String, state: String },
    #[serde(rename = "mouse-scroll")]
    MouseScroll { dx: i32, dy: i32 },
    #[serde(rename = "key-press")]
    KeyPress { key: String },
    #[serde(rename = "type-text")]
    TypeText { text: String },
    #[serde(rename = "media-key")]
    MediaKey { key: String },
    #[serde(rename = "stream-start")]
    StreamStart { width: u32, height: u32, zoom: f32 },
    #[serde(rename = "stream-update")]
    StreamUpdate { width: u32, height: u32, zoom: f32 },
    #[serde(rename = "stream-stop")]
    StreamStop,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ServerMessage {
    #[serde(rename = "connected")]
    Connected { session: String },
    #[serde(rename = "error")]
    Error { code: String, message: String },
}
```

Keep internal value objects (`MouseButton`, `ButtonState`, etc.) for the input execution layer.
Update all [use](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs#509-522)/`mod` references.

#### 1.2 — Rewrite [server.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs) message handling

**File**: [server.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs)

- **On connect**: Send `ServerMessage::Connected { session: uuid }` as JSON text.
- **Main loop**: Parse `ClientMessage` with `serde_json::from_str(&text)`, match on variants.
- **Heartbeat**: Remove custom heartbeat task/channels. Send `Message::Ping(vec![])` every 5s. Track last pong time; close if >15s stale.
- **Screen frames**: Send `Message::Binary(jpeg_bytes)` instead of JSON text with base64.
- **Stream stop**: Use `CancellationToken` (from `tokio_util`) to cleanly stop the streaming task.

#### 1.3 — Update [screen_capture.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture.rs)

**File**: [screen_capture.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture.rs)

- Return `Result<Vec<u8>>` (raw JPEG bytes) instead of [ScreenFrame](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart#170-219) with base64.
- Remove `base64` import and encoding.
- Remove cursor_x/y, monitor_id from return.

---

### Phase 2: Persistent Capture Session

#### 2.1 — New `capture_manager.rs`

**New file**: `pc/src/infrastructure/capture_manager.rs`

```rust
pub struct CaptureManager {
    frame_buffer: Arc<Mutex<Option<FrameBuffer>>>,  // latest frame from WGC
    frame_seq: Arc<AtomicU64>,                       // incremented on each new frame
    monitors: Vec<MonitorInfo>,                      // cached monitor layout
    viewport: (u32, u32, f32),                       // (width, height, zoom)
}
```

- [new(w, h, zoom)](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs#63-73) → enumerate monitors (cached), start persistent WGC sessions.
- `PersistentCaptureHandler::on_frame_arrived()` → stores frame in buffer, does NOT call [stop()](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs#121-126).
- `get_latest_jpeg(last_seq)` → if no new frame, return `None` (skip-if-unchanged). Else: crop, convert, encode JPEG, return `Some((bytes, seq))`.
- `update_viewport(w, h, zoom)` → update capture params.
- [stop()](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs#121-126) → stop all capture sessions.

#### 2.2 — Fix monitor enumeration

**File**: [screen_capture_utils.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture_utils.rs)

Replace grid scan with `EnumDisplayMonitors(NULL, NULL, Some(monitor_enum_proc), ...)` — the callback already exists at line 38. Remove `#[allow(dead_code)]`.

Rewrite coordinate math to use logical-first algorithm (see section 3 above).

Cache result in `CaptureManager`.

---

### Phase 3: Client Protocol Rewrite

#### 3.1 — Update `command.dart`

**File**: [command.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/domain/entities/command.dart)

Replace nested command classes with flat `ClientMessage` static factory methods.

#### 3.2 — Binary frames in [websocket_client.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart)

**File**: [websocket_client.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart)

```dart
_channel?.stream.listen((data) {
    if (data is Uint8List) {
        // Binary = screen frame (raw JPEG bytes)
        _messageController.add({'type': 'screen_frame_binary', 'bytes': data});
    } else if (data is String) {
        final message = jsonDecode(data) as Map<String, dynamic>;
        _handleMessage(message);
    }
});
```

Update [_handleMessage()](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart#119-156): `'connected'` (was `'connection_accepted'`), remove `'heartbeat'` case.
Remove [_sendHeartbeatAck()](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart#214-228).

#### 3.3 — Update [screen_stream_service.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart)

**File**: [screen_stream_service.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart)

- [stopStreaming()](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart#94-108): send `stream-stop` to server before clearing local state.
- [_handleScreenFrame()](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart#170-219): receive `Uint8List` JPEG directly, no base64 decode.
- Remove [_areBytesEqual()](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart#228-236), `_lastImageData`.

#### 3.4 — Streaming lifecycle in [home_screen.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/presentation/screens/home_screen.dart)

**File**: [home_screen.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/presentation/screens/home_screen.dart)

Add `WidgetsBindingObserver`. Track `_wasStreamingBeforePause`.

- `onDestinationSelected`: if leaving touchpad (index 1) while streaming → send `stream-stop`, save flag. If returning to touchpad with flag set → send `stream-start`.
- `didChangeAppLifecycleState`: paused/inactive → stop streaming, save flag. Resumed → restart if on touchpad with flag set.

---

### Phase 4: Pixel Operation Optimizations

**File**: [screen_capture_utils.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture_utils.rs) (or new `capture_manager.rs`)

| What | Old | New |
|------|-----|-----|
| Canvas clear | `put_pixel()` loop | `vec![0u8; w*h*4]` |
| BGRA→RGBA | byte-by-byte chunks | `chunks_exact_mut(4)` + `swap(0,2)` |
| Compositing | `get_pixel`/`put_pixel` | row-span `copy_from_slice` |

---

### Phase 5: Reduce Logging

- Server: per-frame `debug!()` → `trace!()`. Keep `info!()` for lifecycle events.
- Client: remove all per-frame `print()`. Keep `debugPrint()` for lifecycle events.

---

## Verification Plan

### Automated
- `cargo test` — update test JSON to flat format
- New tests for `ClientMessage` deserialization
- New test for binary frame output

### Manual
1. Connect → verify `connected` message
2. Start streaming → binary JPEG frames display
3. Navigate away from touchpad → server stops capturing
4. Return to touchpad → streaming auto-restarts
5. App background → server stops; app foreground → resumes
6. Kill client → server detects via ping timeout within 15s
7. FPS comparison before/after persistent capture
