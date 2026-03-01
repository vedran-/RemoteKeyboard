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

All messages are JSON-encoded with the following structure:

```json
{
  "type": "<message_type>",
  "payload": { ... },
  "timestamp": <unix_epoch_ms>,
  "id": "<optional-message-id>"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Message type identifier |
| `payload` | object | Yes | Message-specific data (can be `{}`) |
| `timestamp` | number | Yes | Unix epoch milliseconds (for ordering, latency calc) |
| `id` | string | No | Unique message ID for ack/nack correlation |

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

### 3.4 Error Responses

```json
{
  "type": "error",
  "payload": {
    "code": "error_code",
    "message": "Human readable message",
    "original_message_id": "id-of-failed-msg"
  },
  "timestamp": 1709012345678
}
```

**Error Codes:**
| Code | Description |
|------|-------------|
| `invalid_message` | JSON parse error or unknown type |
| `invalid_payload` | Payload schema validation failed |
| `not_connected` | Operation requires active connection |
| `input_failed` | Failed to simulate input on PC |
| `server_error` | Internal server error |

---

## 4. Message Types

### 4.1 Control Messages (Bidirectional)

#### 4.1.1 Connection Accepted (PC → Mobile)

Sent when PC accepts a new connection.

```json
{
  "type": "connection_accepted",
  "payload": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "timestamp": 1709012345678
}
```

#### 4.1.2 Connection Rejected (PC → Mobile)

Sent when PC rejects a connection (already connected, etc.).

```json
{
  "type": "connection_rejected",
  "payload": {
    "reason": "Another client is already connected"
  },
  "timestamp": 1709012345678
}
```

#### 4.1.3 Heartbeat (PC → Mobile)

Sent periodically by PC to verify connection.

```json
{
  "type": "heartbeat",
  "payload": {
    "server_time": 1709012345678
  },
  "timestamp": 1709012345678
}
```

#### 4.1.4 Heartbeat Acknowledgment (Mobile → PC)

```json
{
  "type": "heartbeat_ack",
  "payload": {
    "server_time": 1709012345678,
    "client_time": 1709012345680
  },
  "timestamp": 1709012345680
}
```

#### 4.1.5 Ping/Pong (Bidirectional)

For latency measurement.

```json
{
  "type": "ping",
  "payload": {
    "sent_at": 1709012345678
  },
  "timestamp": 1709012345678
}
```

```json
{
  "type": "pong",
  "payload": {
    "sent_at": 1709012345678,
    "received_at": 1709012345680
  },
  "timestamp": 1709012345680
}
```

---

### 4.2 Mouse Commands (Mobile → PC)

#### 4.2.1 Mouse Move (Relative)

```json
{
  "type": "mouse_move",
  "payload": {
    "dx": 10,
    "dy": -5
  },
  "timestamp": 1709012345678
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dx` | integer | Horizontal delta (pixels) |
| `dy` | integer | Vertical delta (pixels) |

#### 4.2.2 Mouse Move Absolute

```json
{
  "type": "mouse_move_absolute",
  "payload": {
    "x": 1920,
    "y": 1080
  },
  "timestamp": 1709012345678
}
```

| Field | Type | Description |
|-------|------|-------------|
| `x` | integer | X coordinate (0 = left) |
| `y` | integer | Y coordinate (0 = top) |

#### 4.2.3 Mouse Click

```json
{
  "type": "mouse_click",
  "payload": {
    "button": "left",
    "action": "press"
  },
  "timestamp": 1709012345678
}
```

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `button` | string | `left`, `right`, `middle` | Mouse button |
| `action` | string | `press`, `release` | Button state |

**Note:** A full click is `press` followed by `release`.

#### 4.2.4 Mouse Scroll

```json
{
  "type": "mouse_scroll",
  "payload": {
    "dx": 0,
    "dy": -120
  },
  "timestamp": 1709012345678
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dx` | integer | Horizontal scroll (positive = right) |
| `dy` | integer | Vertical scroll (positive = down) |

**Note:** Windows uses 120 per scroll "tick".

---

### 4.3 Keyboard Commands (Mobile → PC)

#### 4.3.1 Key Press

```json
{
  "type": "key_press",
  "payload": {
    "key": "A"
  },
  "timestamp": 1709012345678
}
```

#### 4.3.2 Key Release

```json
{
  "type": "key_release",
  "payload": {
    "key": "A"
  },
  "timestamp": 1709012345678
}
```

#### 4.3.3 Type Text

Optimized for typing - sends whole string at once.

```json
{
  "type": "type_text",
  "payload": {
    "text": "Hello, World!"
  },
  "timestamp": 1709012345678
}
```

#### 4.3.4 Key Codes

**Supported Keys:**

| Category | Keys |
|----------|------|
| Letters | `A`-`Z` |
| Numbers | `0`-`9` |
| Function | `F1`-`F12` |
| Control | `Control`, `Alt`, `Shift`, `Meta` (Windows/Command) |
| Navigation | `Enter`, `Backspace`, `Tab`, `Escape`, `Space` |
| Arrows | `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight` |
| Special | `Delete`, `Insert`, `Home`, `End`, `PageUp`, `PageDown` |
| Symbols | `Plus`, `Minus`, `Equal`, `BracketLeft`, `BracketRight`, `Semicolon`, `Quote`, `Backquote`, `Backslash`, `Comma`, `Period`, `Slash`, `Slash` |

---

### 4.4 Media Commands (Mobile → PC)

#### 4.4.1 Media Key

```json
{
  "type": "media_key",
  "payload": {
    "action": "play_pause"
  },
  "timestamp": 1709012345678
}
```

**Supported Actions:**

| Action | Description |
|--------|-------------|
| `play_pause` | Toggle play/pause |
| `next` | Next track |
| `prev` | Previous track |
| `vol_up` | Volume up |
| `vol_down` | Volume down |
| `mute` | Mute/unmute |

---

### 4.5 Custom Commands (Mobile → PC)

#### 4.5.1 Custom Action

Extensible command for user-defined actions.

```json
{
  "type": "custom_action",
  "payload": {
    "id": "launch_youtube",
    "payload": {
      "url": "https://youtube.com"
    }
  },
  "timestamp": 1709012345678
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Action identifier (configured on PC) |
| `payload` | object | Action-specific data |

---

## 5. Batch Commands (Optimization)

For high-frequency updates (touchpad), multiple commands can be batched:

```json
{
  "type": "batch",
  "payload": {
    "commands": [
      { "type": "mouse_move", "payload": { "dx": 5, "dy": -2 } },
      { "type": "mouse_move", "payload": { "dx": 3, "dy": -1 } },
      { "type": "mouse_move", "payload": { "dx": 2, "dy": 0 } }
    ]
  },
  "timestamp": 1709012345678
}
```

---

## 6. Protocol Extension Points

### 6.1 Future UDP Transport

For high-frequency mouse updates, UDP can be used with a simpler binary format:

```
Byte Layout (12 bytes per mouse update):
[0-1]   Sequence number (u16, big-endian)
[2-3]   Command type (u16, 0x0001 = mouse_move)
[4-7]   dx (i16, big-endian)
[8-11]  dy (i16, big-endian)
```

### 6.2 Future Screen Streaming

```json
{
  "type": "screen_frame",
  "payload": {
    "format": "h264",
    "width": 1920,
    "height": 1080,
    "data": "<base64-encoded-frame>"
  },
  "timestamp": 1709012345678
}
```

---

## 7. Implementation Notes

### 7.1 Message Ordering

- Messages are ordered by `timestamp`
- Receiver should process in timestamp order
- Late messages (>100ms old) may be dropped for mouse moves

### 7.2 Connection Resilience

- Mobile should buffer commands during disconnection
- PC should not acknowledge every command (overhead)
- Heartbeat interval: 5 seconds
- Connection timeout: 30 seconds without heartbeat

### 7.3 Performance

- Target: 60 messages/second for touchpad
- Batch updates if network can't keep up
- Compress large text inputs (future optimization)

---

*Last Updated: 2026-02-27*
*Version: 1.0*
