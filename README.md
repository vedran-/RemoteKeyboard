# RemoteKeyboard

**Control your PC from your phone** - A two-sided application for remote PC control via virtual touchpad, keyboard, and media keys.

![Status](https://img.shields.io/badge/status-Complete-green)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-lightgrey)
![Tests](https://img.shields.io/badge/tests-99%20passing-brightgreen)
![CI](https://github.com/vedran-/RemoteKeyboard/actions/workflows/ci.yml/badge.svg)
![Release](https://img.shields.io/github/v/release/vedran-/RemoteKeyboard?label=latest%20release)

---

## 🎯 Overview

RemoteKeyboard lets you control your PC (especially useful for PC connected to TV) from your Android or Windows phone using:

- **Virtual Touchpad** - Move cursor, click, scroll
- **Virtual Keyboard** - Type text on your PC
- **Media Keys** - Play/Pause, Next, Previous, Volume control

```
┌──────────────┐                          ┌──────────────┐
│   Mobile     │      WebSocket           │      PC      │
│   (Flutter)  │◄───────────────────────►│    (Rust)    │
│              │       (Local LAN)        │              │
└──────────────┘                          └──────────────┘
  Touchpad                                  Controls PC
  Keyboard                                  (mouse, keyboard,
  Media Keys                                 media keys)
```

---

## 📋 Features

### Core Features
- ✅ Automatic device discovery on local network (network scanning)
- ✅ Virtual touchpad with cursor control
- ✅ Tap-to-click (left/right click)
- ✅ Two-finger scroll
- ✅ Virtual keyboard for text input
- ✅ Media keys (Play/Pause, Next, Prev, Volume, Mute)
- ✅ Windows Firewall auto-configuration
- ✅ Low latency (< 50ms target)

### Smart Connection Features
- ✅ **Auto-reconnect** - Automatically reconnects on connection loss with exponential backoff
- ✅ **Cold start reconnect** - Automatically reconnects to last PC on app restart
- ✅ **Connection monitoring** - Heartbeat-based connection health monitoring
- ✅ **Network permissions** - Full Android network support
- ✅ **Multi-monitor support** - Smooth cursor movement across multiple monitors
- ✅ **Physical cursor coordinates** - True physical pixels for multi-DPI setups (4K+2K)
- ✅ **Screen capture streaming** - Stream screen area around cursor (5 FPS, configurable zoom)
- ✅ **Mobile screen display** - View PC screen in touchpad area with cursor indicator
- ✅ **Aspect ratio preservation** - No stretching, black letterboxing
- ✅ **Bandwidth optimization** - Server-side downscaling (max 400px, Triangle filter)

---

## 📥 Downloads

**Get the latest pre-built binaries:**

[![GitHub Release](https://img.shields.io/github/v/release/vedran-/RemoteKeyboard?label=Download%20Latest&style=for-the-badge)](https://github.com/vedran-/RemoteKeyboard/releases/latest)

**Or visit:** https://github.com/vedran-/RemoteKeyboard/releases

| File | Description | Size |
|------|-------------|------|
| `RemoteKeyboard-Server-v*.exe` | PC Server (Windows) | ~3.3 MB |
| `RemoteKeyboard-Client-v*.exe` | Mobile Client (Windows) | ~30 MB |
| `RemoteKeyboard-Client-v*-arm64.apk` | Mobile Client (Android ARM64) | ~50 MB |
| `RemoteKeyboard-Client-v*-armv7.apk` | Mobile Client (Android ARMv7) | ~50 MB |

---

## 🚀 Quick Start

### 1. Start PC Server

**Download and run:** `RemoteKeyboard-Server-v*.exe`

Or build from source:
```bash
cd pc
cargo run --release
```

**You should see:**
```
🎹 RemoteKeyboard PC
===================
🔒 Configuring Windows Firewall...
✅ Firewall rule configured: RemoteKeyboard-8765
📡 Starting mDNS advertiser...
✅ mDNS advertising: _remotekeyboard._tcp.local.
🔌 Starting WebSocket server...
✅ WebSocket server listening on port 8765
📱 Ready to receive commands from mobile!
```

### 2. Install Mobile App

**Download and install:** `RemoteKeyboard-Client-v*.exe` (Windows) or `.apk` (Android)

Or build from source:
```bash
cd mobile
flutter build windows --release    # Windows
flutter build apk --release        # Android
```

### 3. Connect

1. **Make sure both devices are on the same WiFi network**

2. **Find your PC's IP address:**
   ```bash
   ipconfig
   # Look for IPv4 Address, e.g., 192.168.1.100
   ```

3. **On mobile app:**
   - Open app → Go to "Connect" tab
   - **Option A (Auto)**: Wait for network scan
   - **Option B (Manual)**: Tap "Add PC Manually" → Enter IP and port `8765`
   - Tap connect icon (🔌)

4. **Start using:**
   - **Touchpad**: Drag to move cursor, tap to click
   - **Keyboard**: Type text on PC
   - **Media**: Control media playback

---

## 🔧 Troubleshooting

### Mobile Can't Connect

**Check firewall:**
```bash
netsh advfirewall firewall show rule name="RemoteKeyboard-8765"
```

**Add firewall rule manually (as Administrator):**
```bash
netsh advfirewall firewall add rule name="RemoteKeyboard-8765" dir=in action=allow protocol=TCP localport=8765
```

**Check port is listening:**
```bash
netstat -ano | findstr :8765
```

### Build Errors

**PC:**
```bash
rustup update && cargo clean && cargo build --release
```

**Mobile:**
```bash
flutter clean && flutter pub get && flutter build windows --release
```

---

## 🏗️ Architecture

This project uses **Domain-Driven Design (DDD)** with layered architecture:

- **Domain Layer** - Business logic, entities, commands
- **Application Layer** - Use cases, ports
- **Infrastructure Layer** - Adapters (WebSocket, mDNS, input simulation)
- **Presentation Layer** - UI (Flutter mobile, Rust console)

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter (Dart) |
| PC App | Rust |
| Input Simulation | enigo crate |
| Communication | WebSocket (TCP) |
| Discovery | mDNS / Network Scanning |

See [Architecture Decision Records](docs/DECISIONS.md) for rationale.

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [SPECIFICATION.md](docs/SPECIFICATION.md) | Requirements |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design |
| [PROTOCOL.md](docs/PROTOCOL.md) | Message formats |
| [ROADMAP.md](docs/ROADMAP.md) | Development plan |
| [DECISIONS.md](docs/DECISIONS.md) | Architecture decisions |
| [GITIGNORE.md](docs/GITIGNORE.md) | Git configuration |

---

## 📊 Status

| Component | Status | Tests |
|-----------|--------|-------|
| PC Server | ✅ Complete | 119 passing |
| Mobile Windows | ✅ Complete | 71 passing |
| Mobile Android | ✅ Complete | 71 passing |

**Total:** 190 tests passing ✅

### Completed Features (Latest)
- ✅ Screen streaming (5 FPS, multi-monitor, RGBA→RGB fix, no flickering)
- ✅ Server restart fix (streaming works multiple times per session)
- ✅ Aspect ratio preservation (no stretching, black letterboxing)
- ✅ Bandwidth optimization (server-side downscaling to max 400px)
- ✅ Client-controlled capture dimensions (WxH based on touchpad)
- ✅ Mobile screen display (touchpad shows PC screen capture)
- ✅ Multi-monitor mouse support (clamping workaround)
- ✅ Auto-reconnect with exponential backoff (1s → 2s → 3s → 4s → 5s)
- ✅ Cold start reconnect to last PC
- ✅ Heartbeat-based connection monitoring
- ✅ Android network permissions fix
- ✅ Smart notification system (dismissible, auto-dismiss)
- ✅ Comprehensive integration tests

---

## 🔨 Building from Source

### Prerequisites

**PC:**
- Rust 1.75+ ([install](https://rustup.rs))

**Mobile:**
- Flutter 3.x+ ([install](https://docs.flutter.dev/get-started/install))
- Android Studio (for Android builds)
- `flutter config --enable-windows-desktop` (for Windows builds)

### Build Commands

```bash
# PC Server
cd pc && cargo build --release

# Mobile Windows
cd mobile && flutter build windows --release

# Mobile Android
cd mobile && flutter build apk --release
```

See full build instructions in [README.md](README.md#-building-from-source) (this file has detailed sections).

---

## 🤝 Contributing

Contributions are welcome!

**How to help:**
- Report bugs or feature requests
- Submit PRs (follow DDD architecture)
- Improve documentation
- Test on different devices

**Guidelines:**
- Follow DDD layer structure
- Write tests for domain logic
- Update docs when changing architecture

---

## 📝 License

MIT License

---

## 🙏 Acknowledgments

- [enigo](https://github.com/enigo-rs/enigo) - Input simulation
- [Flutter](https://flutter.dev/) - Mobile framework
- [mdns-sd](https://github.com/keepsimple1/mdns-sd) - mDNS library

---

*Last Updated: 2026-03-01*  
*Version: 1.0.0*  
*Builds: Server 3.3 MB | Client Win 30 MB | Client Android 50-160 MB*
