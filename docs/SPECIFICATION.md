# RemoteKeyboard - Specification

## Overview

RemoteKeyboard is a two-sided application that allows users to control their PC from a mobile device (Android/iOS) using a virtual touchpad, keyboard, and media control panel.

---

## 1. Functional Requirements

### 1.1 Mobile Application (Remote)

#### 1.1.1 Touchpad Mode
- **F1-Touchpad**: Single-finger drag moves PC cursor (relative movement)
- **F1-Touchpad**: Single-tap = left click
- **F1-Touchpad**: Two-finger tap = right click
- **F1-Touchpad**: Two-finger scroll = vertical/horizontal scroll
- **F1-Touchpad**: Configurable sensitivity

#### 1.1.2 Keyboard Mode
- **F2-Keyboard**: Standard QWERTY keyboard for text input
- **F2-Keyboard**: Real-time character transmission to PC
- **F2-Keyboard**: Support for special keys (Enter, Backspace, Tab, Escape, Arrow keys)

#### 1.1.3 Media Keys Panel
- **F3-Media**: Dedicated media control buttons:
  - Play/Pause (toggle)
  - Next Track
  - Previous Track
  - Volume Up
  - Volume Down
  - Mute
- **F3-Media**: Extensible custom key buttons (user-configurable)
- **F3-Media**: Quick launch buttons (e.g., "Open YouTube", "Open Browser")

#### 1.1.4 Connection Management
- **F4-Discovery**: Automatic device discovery on local network (mDNS)
- **F4-Discovery**: Manual connection via IP address
- **F4-Discovery**: Connection status indicator
- **F4-Discovery**: Auto-reconnect on disconnection

### 1.2 PC Application (Host)

#### 1.2.1 Input Simulation
- **H1-Input**: Simulate mouse movement (absolute and relative)
- **H1-Input**: Simulate mouse clicks (left, right, middle, double-click)
- **H1-Input**: Simulate mouse scroll (vertical, horizontal)
- **H1-Input**: Simulate keyboard key press/release
- **H1-Input**: Simulate text typing
- **H1-Input**: Simulate media keys (play, pause, next, prev, volume)
- **H1-Input**: Simulate custom key combinations (shortcuts)

#### 1.2.2 Network Services
- **H2-Network**: Advertise presence on local network via mDNS
- **H2-Network**: Accept WebSocket connections from mobile clients
- **H2-Network**: Handle multiple connection attempts (single active connection)
- **H2-Network**: Graceful disconnection handling

#### 1.2.3 User Interface
- **H3-UI**: System tray icon (always accessible)
- **H3-UI**: Connection status display
- **H3-UI**: Basic settings (port, auto-start, minimize to tray)
- **H3-UI**: Start/stop server

---

## 2. Non-Functional Requirements

### 2.1 Performance
- **NFR1**: Touchpad latency < 50ms (end-to-end)
- **NFR2**: Support 60Hz touchpad update rate
- **NFR3**: PC application memory usage < 50MB
- **NFR4**: Mobile application startup < 3 seconds

### 2.2 Compatibility
- **NFR5**: PC: Windows 11 (primary), Windows 10 (secondary)
- **NFR6**: Mobile: Android 10+ (primary), iOS 15+ (secondary)
- **NFR7**: Network: IPv4 local network (same subnet)

### 2.3 Security
- **NFR8**: Optional connection PIN/password (future)
- **NFR9**: No data persisted on PC (privacy)

### 2.4 Extensibility
- **NFR10**: Transport layer abstraction (TCP/UDP pluggable)
- **NFR11**: Command pattern for easy new input types
- **NFR12**: Plugin system for custom actions (future)

---

## 3. Domain Model

### 3.1 Core Entities

```
Command (Domain Object)
├── MouseCommand
│   ├── Move { dx: i32, dy: i32 }
│   ├── MoveAbsolute { x: u32, y: u32 }
│   ├── Click { button: MouseButton }
│   └── Scroll { dx: i32, dy: i32 }
├── KeyboardCommand
│   ├── KeyPress { key: KeyCode }
│   ├── KeyRelease { key: KeyCode }
│   └── TypeText { text: String }
├── MediaCommand
│   ├── PlayPause
│   ├── NextTrack
│   ├── PrevTrack
│   ├── VolumeUp
│   ├── VolumeDown
│   └── Mute
└── CustomCommand
    └── Action { id: String, payload: Json }

Device (Domain Object)
├── id: String
├── name: String
├── address: IpAddr
├── port: u16
└── status: DeviceStatus

Connection (Domain Object)
├── device: Device
├── transport: TransportType
├── established_at: DateTime
└── is_active: bool
```

### 3.2 Value Objects

```
MouseButton { Left | Right | Middle }
KeyCode { A-Z, 0-9, F1-F12, Enter, Backspace, Tab, Escape, Arrow*, ... }
MediaKey { Play, Pause, Next, Prev, VolumeUp, VolumeDown, Mute }
TransportType { WebSocket | Udp | Future }
DeviceStatus { Available | Connecting | Connected | Unavailable }
```

### 3.3 Domain Services

```
InputService (Port)
├── execute_mouse(command: MouseCommand)
├── execute_keyboard(command: KeyboardCommand)
├── execute_media(command: MediaCommand)
└── execute_custom(command: CustomCommand)

DiscoveryService (Port)
├── advertise() -> Self
├── discover() -> Stream<Device>
└── stop()

TransportService (Port)
├── send(command: Command)
├── listen() -> Stream<Command>
├── connect(device: Device)
└── disconnect()
```

---

## 4. Technical Specifications

### 4.1 Tech Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Mobile App | Flutter | 3.x |
| Mobile State | Riverpod/BLoC | Latest |
| PC Backend | Rust | 1.75+ |
| PC Frontend | Tauri | 2.x |
| PC UI | Svelte/React | Latest |
| Communication | WebSocket | RFC 6455 |
| Discovery | mDNS | RFC 6762 |
| Input Simulation (PC) | enigo | 0.1+ |

### 4.2 Network Protocol

#### 4.2.1 Service Discovery
- **Service Type**: `_remotekeyboard._tcp`
- **TXT Records**: `version=1.0`, `name=PC-Name`, `protocol=websocket`
- **Port**: Configurable (default: 8765)

#### 4.2.2 WebSocket Protocol
- **URL**: `ws://<device-ip>:<port>/remote`
- **Message Format**: JSON
- **Encoding**: UTF-8

```json
{
  "type": "mouse_move",
  "payload": { "dx": 10, "dy": -5 },
  "timestamp": 1709012345678
}
```

#### 4.2.3 Message Types

| Direction | Type | Payload Schema |
|-----------|------|----------------|
| Mobile→PC | `mouse_move` | `{ dx: number, dy: number }` |
| Mobile→PC | `mouse_click` | `{ button: "left" \| "right" \| "middle", action: "press" \| "release" }` |
| Mobile→PC | `mouse_scroll` | `{ dx: number, dy: number }` |
| Mobile→PC | `key_press` | `{ key: string }` |
| Mobile→PC | `key_release` | `{ key: string }` |
| Mobile→PC | `type_text` | `{ text: string }` |
| Mobile→PC | `media_key` | `{ action: "play_pause" \| "next" \| "prev" \| "vol_up" \| "vol_down" \| "mute" }` |
| Mobile→PC | `custom_action` | `{ id: string, payload: object }` |
| PC→Mobile | `connection_accepted` | `{ session_id: string }` |
| PC→Mobile | `connection_rejected` | `{ reason: string }` |
| PC→Mobile | `heartbeat` | `{ timestamp: number }` |
| Mobile→PC | `heartbeat_ack` | `{ timestamp: number }` |
| Both | `ping` | `{ timestamp: number }` |
| Both | `pong` | `{ timestamp: number }` |

### 4.3 Project Structure

```
RemoteKeyboard/
├── docs/
│   ├── SPECIFICATION.md       (this file)
│   ├── ARCHITECTURE.md        (system design, DDD layers)
│   ├── PROTOCOL.md            (detailed protocol spec)
│   ├── ROADMAP.md             (phases, milestones)
│   └── DECISIONS.md           (ADRs)
├── pc/
│   ├── src/
│   │   ├── domain/            (entities, value objects, domain services)
│   │   ├── application/       (use cases, ports)
│   │   ├── infrastructure/    (adapters: WebSocket, mDNS, enigo)
│   │   ├── presentation/      (Tauri UI)
│   │   └── main.rs
│   ├── Cargo.toml
│   └── tauri.conf.json
├── mobile/
│   ├── lib/
│   │   ├── domain/            (entities, value objects)
│   │   ├── application/       (providers, use cases)
│   │   ├── infrastructure/    (WebSocket, mDNS)
│   │   ├── presentation/      (Flutter UI, screens)
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── android/ios configs
└── README.md
```

---

## 5. Future Enhancements (Out of Scope for MVP)

- **F-UDP**: High-frequency mouse polling over UDP
- **F-Screen**: Screen mirroring to mobile
- **F-File**: File transfer between devices
- **F-Voice**: Voice input / voice commands
- **F-Cloud**: Remote connection (outside LAN) via relay
- **F-Macro**: Record and playback macros
- **F-Profile**: User profiles with custom layouts
- **F-Haptic**: Haptic feedback on mobile

---

## 6. Acceptance Criteria (MVP)

- [ ] PC app advertises on LAN via mDNS
- [ ] Mobile app discovers PC automatically
- [ ] Mobile touchpad moves PC cursor smoothly
- [ ] Mobile touchpad click = PC mouse click
- [ ] Mobile keyboard types text on PC
- [ ] Media keys (Play/Pause, Next, Prev, Vol+, Vol-) work on PC
- [ ] Connection survives screen sleep/wake
- [ ] PC app runs in system tray
- [ ] Latency < 100ms for all inputs

---

*Last Updated: 2026-02-27*
*Version: 1.0*
