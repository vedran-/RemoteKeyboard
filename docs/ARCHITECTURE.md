# RemoteKeyboard - Architecture

## 1. Architectural Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         MOBILE (Flutter)                                │
├─────────────────────────────────────────────────────────────────────────┤
│  Presentation Layer                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │  Touchpad    │  │   Keyboard   │  │  Media Keys  │                  │
│  │   Screen     │  │    Screen    │  │    Screen    │                  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                  │
│         │                 │                  │                          │
│         └─────────────────┴──────────────────┘                          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │       Application Layer           │                          │
│         │  (InputHandlers, ConnectionMgr)   │                          │
│         └─────────────────┬─────────────────┘                          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │        Domain Layer               │                          │
│         │  (Entities, Value Objects,        │                          │
│         │   Domain Services, Commands)      │                          │
│         └─────────────────┬─────────────────┘                          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │     Infrastructure Layer          │                          │
│         │  ┌────────────┐  ┌─────────────┐ │                          │
│         │  │ WebSocket  │  │    mDNS     │ │                          │
│         │  │  Adapter   │  │   Adapter   │ │                          │
│         │  └────────────┘  └─────────────┘ │                          │
│         └──────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────┘
                              │    ▲
                    WebSocket │    │ mDNS
                              ▼    │
┌─────────────────────────────────────────────────────────────────────────┐
│                          PC (Rust + Tauri)                              │
├─────────────────────────────────────────────────────────────────────────┤
│  Presentation Layer (Tauri + Svelte/React)                              │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │  System Tray Icon + Status Window                        │          │
│  └──────────────────────────────────────────────────────────┘          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │       Application Layer           │                          │
│         │    (CommandHandlers, Ports)       │                          │
│         └─────────────────┬─────────────────┘                          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │        Domain Layer               │                          │
│         │  (Entities, Value Objects,        │                          │
│         │   Domain Services, Commands)      │                          │
│         └─────────────────┬─────────────────┘                          │
│                           │                                             │
│         ┌─────────────────▼─────────────────┐                          │
│         │     Infrastructure Layer          │                          │
│         │  ┌────────────┐  ┌─────────────┐ │                          │
│         │  │ WebSocket  │  │    mDNS     │ │                          │
│         │  │  Adapter   │  │   Adapter   │ │                          │
│         │  └────────────┘  └─────────────┘ │                          │
│         │  ┌─────────────────────────────┐ │                          │
│         │  │    Input Adapter (enigo)    │ │                          │
│         │  └─────────────────────────────┘ │                          │
│         └──────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Domain-Driven Design Breakdown

### 2.1 Strategic Design - Bounded Contexts

```
┌─────────────────────────────────────────────────────────────┐
│                   REMOTE CONTROL CONTEXT                    │
│                                                             │
│  Core Domain: Transform mobile input into PC commands       │
│  - Touchpad gestures → Mouse commands                       │
│  - Keyboard input → Keyboard commands                       │
│  - Media buttons → Media commands                           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   DEVICE DISCOVERY CONTEXT                  │
│                                                             │
│  Supporting Domain: Find and connect to devices             │
│  - mDNS advertisement                                       │
│  - Device registry                                          │
│  - Connection management                                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   INPUT SIMULATION CONTEXT                  │
│                                                             │
│  Supporting Domain: Execute commands on PC                  │
│  - Mouse simulation                                         │
│  - Keyboard simulation                                      │
│  - Media key simulation                                     │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Domain Layer (Shared between PC and Mobile)

#### Entities

```rust
// Command.rs - Core domain entity
pub enum Command {
    Mouse(MouseCommand),
    Keyboard(KeyboardCommand),
    Media(MediaCommand),
    Custom(CustomCommand),
}

pub struct MouseCommand {
    pub action: MouseAction,
    pub data: MouseData,
}

pub enum MouseAction {
    Move,
    MoveAbsolute,
    Click,
    Scroll,
}

pub enum MouseData {
    Relative { dx: i32, dy: i32 },
    Absolute { x: u32, y: u32 },
    Button { button: MouseButton, state: ButtonState },
    Scroll { dx: i32, dy: i32 },
}

// Similar structures for KeyboardCommand, MediaCommand, CustomCommand
```

#### Value Objects

```rust
// Immutable, equality-by-value
pub struct MouseButton(pub u8);  // Left=1, Right=2, Middle=3
pub struct KeyCode(pub String);  // "A", "Enter", "F1", etc.
pub struct MediaKeyCode(pub String);  // "play_pause", "next", etc.
pub struct DeviceId(pub Uuid);
pub struct SessionId(pub Uuid);
```

#### Domain Services (Ports)

```rust
// Abstract interfaces - defined in domain, implemented in infrastructure

// On PC side - executes commands
pub trait InputExecutor: Send + Sync {
    fn execute(&self, command: MouseCommand) -> Result<()>;
    fn execute(&self, command: KeyboardCommand) -> Result<()>;
    fn execute(&self, command: MediaCommand) -> Result<()>;
}

// On Mobile side - sends commands
pub trait CommandSender: Send + Sync {
    fn send(&self, command: &Command) -> Result<()>;
}

// On PC side - receives commands
pub trait CommandReceiver: Send + Sync {
    fn listen(&self) -> BoxStream<Command>;
}

// Both sides - device discovery
pub trait DeviceDiscovery: Send + Sync {
    fn advertise(&self) -> Result<()>;
    fn discover(&self) -> BoxStream<Device>;
}
```

### 2.3 Application Layer

#### Use Cases (PC)

```rust
pub struct HandleIncomingCommand {
    input_executor: Arc<dyn InputExecutor>,
}

impl HandleIncomingCommand {
    pub async fn handle(&self, command: Command) -> Result<()> {
        self.input_executor.execute(command).await
    }
}

pub struct ManageConnection {
    // Connection state management
}
```

#### Use Cases (Mobile)

```rust
pub struct ProcessTouchpadGesture {
    command_sender: Arc<dyn CommandSender>,
    sensitivity: f64,
}

impl ProcessTouchpadGesture {
    pub fn handle(&self, gesture: TouchpadGesture) -> Result<()> {
        let command = self.gesture_to_command(gesture);
        self.command_sender.send(&command)
    }
}

pub struct ProcessKeyPress {
    command_sender: Arc<dyn CommandSender>,
}
```

### 2.4 Infrastructure Layer

#### Adapters (PC)

```
Infrastructure/
├── websocket/
│   ├── server.rs          # WebSocket server (tokio-tungstenite)
│   └── handler.rs         # Connection handler
├── mdns/
│   └── advertiser.rs      # mDNS service (mdns-sd)
├── input/
│   └── enigo_adapter.rs   # enigo wrapper implementing InputExecutor
└── config/
    └── settings.rs        # Configuration management
```

#### Adapters (Mobile)

```
Infrastructure/
├── websocket/
│   └── client.rs          # WebSocket client (web_socket_channel)
├── mdns/
│   └── discoverer.rs      # mDNS client (flutter_mdns or native)
└── config/
    └── settings.dart      # SharedPreferences wrapper
```

---

## 3. Transport Layer Abstraction (Extensibility Point)

### 3.1 Current Design (WebSocket-only)

```rust
// Domain defines the interface
pub trait Transport: Send + Sync {
    fn send(&self, command: &Command) -> Result<()>;
    fn listen(&self) -> BoxStream<Result<Command>>;
    fn connect(&self, device: &Device) -> Result<()>;
    fn disconnect(&self) -> Result<()>;
    fn is_connected(&self) -> bool;
}

// Infrastructure implements WebSocket adapter
pub struct WebSocketTransport {
    connection: Arc<Mutex<WebSocketConnection>>,
}

impl Transport for WebSocketTransport {
    // ... implementation
}
```

### 3.2 Future Extension (UDP support)

```rust
// Add new adapter without changing domain
pub struct UdpTransport {
    socket: Arc<Mutex<UdpSocket>>,
    sequence: AtomicU64,
}

impl Transport for UdpTransport {
    // ... UDP-specific implementation
}

// Or combine both
pub struct HybridTransport {
    tcp: WebSocketTransport,  // For commands, reliability
    udp: UdpTransport,        // For high-freq mouse, speed
}

impl Transport for HybridTransport {
    fn send(&self, command: &Command) -> Result<()> {
        match command {
            Command::Mouse(MouseCommand { action: MouseAction::Move, .. }) => {
                // High-frequency → UDP
                self.udp.send(command)
            }
            _ => {
                // Everything else → TCP (reliable)
                self.tcp.send(command)
            }
        }
    }
}
```

### 3.3 Why This Design Works

1. **Domain doesn't know about TCP/UDP** - only knows `Command`
2. **Transport is swappable** - change in config, no domain changes
3. **Testable** - mock transport for unit tests
4. **Extensible** - add UDP, Bluetooth, WebRTC later

---

## 4. Data Flow

### 4.1 Touchpad → Mouse Movement

```
Mobile:
1. User drags finger on touchpad
2. Flutter GestureDetector captures delta (dx, dy)
3. ProcessTouchpadGesture use case transforms to MouseCommand::Move
4. WebSocketTransport serializes to JSON
5. WebSocketTransport sends via TCP

Network:
6. JSON travels over LAN

PC:
7. WebSocketTransport receives JSON
8. Deserializes to Command::Mouse
9. HandleIncomingCommand use case processes
10. EnigoAdapter.execute(mouse_command)
11. enigo calls Windows SendInput() API
12. OS moves cursor
```

### 4.2 Device Discovery

```
PC (Server):
1. On startup, mDNS Adapter registers service
   - Type: _remotekeyboard._tcp
   - Port: 8765
   - TXT: { name: "LivingRoom-PC", version: "1.0" }
2. Broadcasts on local network

Mobile (Client):
3. On app start, mDNS Discoverer listens
4. Receives PC advertisement
5. Extracts IP, port, metadata
6. Creates Device entity
7. Displays in "Available Devices" list

User Action:
8. User taps device
9. WebSocketTransport.connect(device)
10. Connection established
```

---

## 5. Error Handling Strategy

### 5.1 Domain Errors

```rust
pub enum DomainError {
    ConnectionLost,
    DeviceNotFound,
    InvalidCommand,
    TransportError(String),
    InputSimulationError(String),
}

pub type Result<T> = std::result::Result<T, DomainError>;
```

### 5.2 Recovery Strategies

| Error | Strategy |
|-------|----------|
| Connection lost | Auto-reconnect with exponential backoff |
| Device not found | Refresh discovery, allow manual IP |
| Invalid command | Log, send error to mobile, continue |
| Input simulation fail | Log, attempt fallback method |

---

## 6. Configuration

### 6.1 PC Configuration

```json
{
  "server": {
    "port": 8765,
    "host": "0.0.0.0"
  },
  "discovery": {
    "service_name": "_remotekeyboard._tcp",
    "instance_name": "LivingRoom-PC"
  },
  "input": {
    "mouse_sensitivity": 1.0,
    "enable_absolute_mode": false
  },
  "ui": {
    "start_minimized": true,
    "auto_start": false
  }
}
```

### 6.2 Mobile Configuration

```dart
{
  "connection": {
    "auto_connect": true,
    "last_device_id": "uuid-here",
    "reconnect_interval_ms": 5000
  },
  "touchpad": {
    "sensitivity": 1.0,
    "invert_scroll": false,
    "tap_to_click": true
  },
  "keyboard": {
    "layout": "qwerty",
    "auto_capitalize": true
  }
}
```

---

## 7. Testing Strategy

### 7.1 Unit Tests (Domain + Application)

```rust
// Test domain logic without infrastructure
#[test]
fn test_touchpad_to_mouse_command() {
    let gesture = TouchpadGesture { dx: 10.0, dy: -5.0 };
    let command = gesture.to_command(sensitivity: 1.0);
    assert_eq!(command, MouseCommand::Move { dx: 10, dy: -5 });
}
```

### 7.2 Integration Tests (Infrastructure)

```rust
// Test WebSocket transport with mock server
#[tokio::test]
async fn test_websocket_transport_sends_command() {
    // ...
}
```

### 7.3 E2E Tests (Full Stack)

```dart
// Flutter integration test
testWidgets('touchpad moves PC cursor', (tester) async {
    // ...
});
```

---

## 8. Security Considerations

### 8.1 Current (MVP)

- LAN-only (physically isolated by network boundary)
- No authentication (trusted network assumption)

### 8.2 Future

- PIN-based pairing
- TLS for WebSocket (wss://)
- Device whitelist

---

*Last Updated: 2026-02-27*
*Version: 1.0*
