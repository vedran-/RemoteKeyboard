# RemoteKeyboard - Protocol Specification

## 1. Overview

This document defines the communication protocol between the Mobile (Remote) and PC (Host) applications.

---

## 2. Discovery Protocol (mDNS)

### 2.1 Service Advertisement (PC)

The PC application advertises itself on the local network using mDNS (RFC 6762).

```
Service Type: _remotekeyboard._tcp.local
Port: 8765 (configurable)
TXT Records:
  - version=1.0
  - name=<PC hostname>
  - protocol=websocket
  - path=/remote
```

### 2.2 Service Discovery (Mobile)

The Mobile application queries for services of type `_remotekeyboard._tcp.local`.

**Discovered Device Structure:**
```json
{
  "id": "uuid-generated-from-mac",
  "name": "LivingRoom-PC",
  "address": "192.168.1.100",
  "port": 8765,
  "path": "/remote",
  "version": "1.0"
}
```

---

## 3. Transport Protocol (WebSocket)

### 3.1 Connection

```
URL: ws://<device-address>:<port>/<path>
Example: ws://192.168.1.100:8765/remote
```

### 3.2 Message Format

All messages are JSON-encoded.

### 3.3 Connection Lifecycle

```
┌──────────┐                              ┌──────────┐
│  Mobile  │                              │    PC    │
└────┬─────┘                              └────┬─────┘
     │                                        │
     │────────── WebSocket Connect ──────────>│
     │                                        │
     │<───────── Connection Accepted ─────────│
     │   { type: "connection_accepted",       │
     │     payload: { session_id: "uuid" } }  │
     │                                        │
     │───────┐                                │
     │       │   Active Session               │
     │<──────┤   (Commands flow Mobile→PC)    │
     │       │   (Heartbeats both directions) │
     │───────┘                                │
     │                                        │
     │────────── WebSocket Close ────────────>│
     │                                        │
```

---

## 4. Command Messages (Mobile → PC)

### 4.1 Message Structure

```json
{
  "type": "<command_type>",
  "payload": { ... }
}
```

### 4.2 Mouse Commands (Mobile → PC)

#### 4.2.1 Mouse Move (Relative)

```json
{
  "type": "mouse",
  "payload": {
    "action": "move",
    "data": {
      "dx": 10,
      "dy": -5
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dx` | integer | Horizontal delta (pixels) |
| `dy` | integer | Vertical delta (pixels) |

#### 4.2.2 Mouse Click

```json
{
  "type": "mouse",
  "payload": {
    "action": "click",
    "data": {
      "button": "left",
      "state": "press"
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `button` | string | Mouse button: "left", "right", "middle" |
| `state` | string | Button state: "press", "release" |

#### 4.2.3 Mouse Scroll

```json
{
  "type": "mouse",
  "payload": {
    "action": "scroll",
    "data": {
      "dx": 0,
      "dy": 120
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dx` | integer | Horizontal scroll amount |
| `dy` | integer | Vertical scroll amount (positive = down) |

### 4.3 Keyboard Commands (Mobile → PC)

#### 4.3.1 Key Press

```json
{
  "type": "keyboard",
  "payload": {
    "action": "key_press",
    "data": {
      "key": "A"
    }
  }
}
```

#### 4.3.2 Type Text

```json
{
  "type": "keyboard",
  "payload": {
    "action": "type_text",
    "data": {
      "text": "Hello World"
    }
  }
}
```

### 4.4 Media Commands (Mobile → PC)

```json
{
  "type": "media",
  "payload": "play_pause"
}
```

**Valid media actions:**
- `play_pause` - Toggle play/pause
- `next` - Next track
- `prev` - Previous track
- `vol_up` - Increase volume
- `vol_down` - Decrease volume
- `mute` - Toggle mute

---

## 5. Screen Streaming Protocol

### 5.1 Screen Frame Request (Mobile → PC)

Client requests screen streaming by sending viewport dimensions and zoom level.
Server calculates capture size as `viewport_size × zoom_level` and scales the result to viewport size.

```json
{
  "type": "screen_frame_request",
  "viewport_width": 800,
  "viewport_height": 600,
  "zoom_level": 2.0
}
```

| Field | Type | Description |
|-------|------|-------------|
| `viewport_width` | integer | Client's display area width (pixels) |
| `viewport_height` | integer | Client's display area height (pixels) |
| `zoom_level` | float | Zoom level: 0.1 (zoomed out) to 5.0 (zoomed in) |

**Server Calculation:**
```
capture_width = viewport_width × zoom_level
capture_height = viewport_height × zoom_level

Example: 800×600 viewport at 2.0x zoom
  capture = 1600×1200 (server captures this area around cursor)
  output = 800×600 (server scales down to viewport size)
```

**Zoom Semantics:**
- `1.0x` = Native (1:1 mapping, capture = viewport)
- `> 1.0x` = Zoomed in (capture MORE, scale DOWN, more detail)
- `< 1.0x` = Zoomed out (capture LESS, scale UP, wider view)

### 5.2 Screen Frame (PC → Mobile)

Server sends screen frames as viewport-sized images:

```json
{
  "type": "screen_frame",
  "cursor_x": 400,
  "cursor_y": 300,
  "monitor_id": 0,
  "capture_width": 800,
  "capture_height": 600,
  "data": "<base64-encoded JPEG>"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `cursor_x` | integer | Cursor X position (always viewport_width / 2) |
| `cursor_y` | integer | Cursor Y position (always viewport_height / 2) |
| `monitor_id` | integer | Monitor ID (0 = multi-monitor stitched) |
| `capture_width` | integer | Frame width (equals viewport_width) |
| `capture_height` | integer | Frame height (equals viewport_height) |
| `data` | string | Base64-encoded JPEG image |

---

## 6. Implementation Notes

### 6.1 Message Ordering

- Messages are processed in received order
- Heartbeat interval: 5 seconds
- Connection timeout: 30 seconds without heartbeat

### 6.2 Performance

- Screen streaming: 5 FPS
- Target latency: < 50ms
- Images are JPEG-compressed for bandwidth efficiency

---

*Last Updated: 2026-03-03*
*Version: 2.0 - Server-side zoom with viewport-based capture*
