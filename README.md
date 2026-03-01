# RemoteKeyboard

**Control your PC from your phone** - A two-sided application for remote PC control via virtual touchpad, keyboard, and media keys.

![Status](https://img.shields.io/badge/status-Complete-green)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-lightgrey)
![Tests](https://img.shields.io/badge/tests-165%20passing-brightgreen)
![CI](https://github.com/vedran-/RemoteKeyboard/actions/workflows/ci.yml/badge.svg)
![Release](https://img.shields.io/github/v/release/vedran-/RemoteKeyboard?label=latest%20release)

---

## 🎯 Overview

RemoteKeyboard lets you control your PC (especially useful for PC connected to TV) from your Android or iOS phone using:

- **Virtual Touchpad** - Move cursor, click, scroll
- **Virtual Keyboard** - Type text on your PC
- **Media Keys** - Play/Pause, Next, Previous, Volume control
- **Custom Keys** - Extensible button system for custom actions

```
┌──────────────┐                          ┌──────────────┐
│   Mobile     │      WebSocket +         │      PC      │
│   (Flutter)  │◄────── mDNS ────────────►│     (Rust)   │
│              │       (Local LAN)        │              │
└──────────────┘                          └──────────────┘
  Touchpad                                  Controls PC
  Keyboard                                  (mouse, keyboard,
  Media Keys                                 media keys)
```

---

## 📋 Features (MVP)

- ✅ Automatic device discovery on local network (network scanning)
- ✅ Virtual touchpad with cursor control
- ✅ Tap-to-click (left/right click)
- ✅ Two-finger scroll
- ✅ Virtual keyboard for text input
- ✅ Media keys (Play/Pause, Next, Prev, Volume, Mute)
- ✅ Windows Firewall auto-configuration
- ✅ Low latency (< 50ms target)

---

## 🏗️ Architecture

This project uses **Domain-Driven Design (DDD)** with a layered architecture:

- **Domain Layer** - Business logic, entities, commands
- **Application Layer** - Use cases, ports
- **Infrastructure Layer** - Adapters (WebSocket, mDNS, input simulation)
- **Presentation Layer** - UI (Flutter mobile, Rust console)

### Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter (Dart) |
| PC App | Rust |
| Input Simulation | enigo crate |
| Communication | WebSocket (TCP) |
| Discovery | mDNS / Network Scanning |
| Protocol | JSON over WebSocket |

**Why these choices?** See [Architecture Decision Records](docs/DECISIONS.md).

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [SPECIFICATION.md](docs/SPECIFICATION.md) | Functional + non-functional requirements |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, DDD layers, data flow |
| [PROTOCOL.md](docs/PROTOCOL.md) | WebSocket message formats, mDNS spec |
| [ROADMAP.md](docs/ROADMAP.md) | Development phases, milestones, status |
| [DECISIONS.md](docs/DECISIONS.md) | Architecture Decision Records (ADRs) |

---

## 📥 Downloads (Latest Release)

**Get the latest pre-built binaries:**

[![GitHub Release](https://img.shields.io/github/v/release/vedran-/RemoteKeyboard?label=Download%20Latest&style=for-the-badge)](https://github.com/vedran-/RemoteKeyboard/releases/latest)

**Or visit:** https://github.com/vedran-/RemoteKeyboard/releases

**What to download:**
| File | Description | Size |
|------|-------------|------|
| `RemoteKeyboard-Server-v*.exe` | PC Server (Windows) | ~3.3 MB |
| `RemoteKeyboard-Client-v*.exe` | Mobile Client (Windows) | ~30 MB |
| `RemoteKeyboard-Client-v*-arm64.apk` | Mobile Client (Android ARM64) | ~50 MB |
| `RemoteKeyboard-Client-v*-armv7.apk` | Mobile Client (Android ARMv7) | ~50 MB |

---

## 📥 Installation (Pre-built Binaries)

### PC (Windows)

**Download and Run:**
1. Navigate to: `pc\target\release\`
2. Run: `remote_keyboard_pc.exe`
3. Windows Firewall will prompt - click **Allow**
4. Server starts automatically on port 8765

**Or use the batch file:**
```batchfile
pc\run.bat
```

### Mobile (Android)

**Install APK:**
1. Enable "Install from Unknown Sources" on your Android device
2. Copy APK to device or use ADB:
   ```bash
   adb install mobile/build/app/outputs/flutter-apk/app-debug.apk
   ```
3. Open the app on your device

**APK Location:**
```
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🔨 Building from Source

### Prerequisites

**For PC:**
```bash
# Rust (1.75+)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
rustc --version  # Should be 1.75 or higher
```

**For Mobile (Android & Windows):**
```bash
# Flutter SDK (3.x+)
# Download from: https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor

# Android Studio (for Android SDK)
# Download from: https://developer.android.com/studio

# For Windows desktop builds
flutter config --enable-windows-desktop
```

### Build PC Application

```bash
cd pc

# Build release version
cargo build --release

# Output: pc/target/release/remote_keyboard_pc.exe (≈3.3 MB)
```

### Build Mobile Application

#### Android APK

```bash
cd mobile

# Get dependencies
flutter pub get

# Build debug APK (for testing)
flutter build apk --debug --android-skip-build-dependency-validation

# Output: mobile/build/app/outputs/flutter-apk/app-debug.apk (≈160 MB)

# Build release APK (for distribution)
flutter build apk --release --android-skip-build-dependency-validation

# Output: mobile/build/app/outputs/flutter-apk/release/app-release.apk (≈50 MB)
```

**Install APK on Android device:**
```bash
# Via USB (device must be connected with USB debugging enabled)
flutter install

# Or manually using ADB
adb install mobile\build\app\outputs\flutter-apk\app-debug.apk

# Or copy APK to device and install manually
# (enable "Install from Unknown Sources" in Settings)
```

#### Windows EXE

```bash
cd mobile

# Get dependencies
flutter pub get

# Build debug executable (for testing)
flutter build windows --debug

# Output: mobile/build/windows/x64/runner/Debug/remote_keyboard_mobile.exe (≈30 MB)

# Build release executable (for distribution)
flutter build windows --release

# Output: mobile/build/windows/x64/runner/Release/remote_keyboard_mobile.exe (≈15 MB)
```

**Run Windows app:**
```bash
# Debug build
mobile\build\windows\x64\runner\Debug\remote_keyboard_mobile.exe

# Release build
mobile\build\windows\x64\runner\Release\remote_keyboard_mobile.exe
```

### Quick Build Commands

```bash
# Build everything for testing
cd pc && cargo build --release
cd mobile && flutter build apk --debug && flutter build windows --debug

# Build everything for release
cd pc && cargo build --release
cd mobile && flutter build apk --release && flutter build windows --release
```

### Build Output Locations

| Platform | Build Type | Output Path | Size |
|----------|-----------|-------------|------|
| **PC** | Release | `pc\target\release\remote_keyboard_pc.exe` | ~3.3 MB |
| **Android** | Debug | `mobile\build\app\outputs\flutter-apk\app-debug.apk` | ~160 MB |
| **Android** | Release | `mobile\build\app\outputs\flutter-apk\release\app-release.apk` | ~50 MB |
| **Windows** | Debug | `mobile\build\windows\x64\runner\Debug\remote_keyboard_mobile.exe` | ~30 MB |
| **Windows** | Release | `mobile\build\windows\x64\runner\Release\remote_keyboard_mobile.exe` | ~15 MB |

### Troubleshooting Builds

**Android build fails:**
```bash
flutter clean
flutter pub get
flutter build apk --debug --android-skip-build-dependency-validation
```

**Windows build fails:**
```bash
flutter clean
flutter pub get
flutter build windows --debug
```

**Check Flutter configuration:**
```bash
flutter doctor -v
flutter config --list
```

---

## 🚀 Quick Start

### 1. Start PC Server

**Option A: Double-click** (Windows)
```
pc\run.bat
```

**Option B: Command line**
```bash
cd pc
cargo run --release
```

**Option C: Pre-built binary**
```bash
pc\target\release\remote_keyboard_pc.exe
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

```bash
cd mobile
flutter install
# Or manually: adb install build/app/outputs/flutter-apk/app-debug.apk
```

### 3. Connect

1. **Make sure both devices are on the same WiFi network**

2. **Find your PC's IP address:**
   ```bash
   ipconfig
   # Look for IPv4 Address, e.g., 192.168.1.100
   ```

3. **On mobile app:**
   - Open app
   - Go to "Connect" tab
   - **Option A (Auto)**: Wait for network scan to discover your PC
   - **Option B (Manual)**: Tap "Add PC Manually"
     - Enter PC's IP address
     - Port: `8765`
     - Tap "Add"
   - Tap the connect icon (🔌)

4. **Start using:**
   - **Touchpad** tab: Control mouse (drag to move, tap to click)
   - **Keyboard** tab: Type text on PC
   - **Media** tab: Control media playback

---

## 🔧 Troubleshooting

### Mobile Can't Connect to PC

**Check Firewall:**
```bash
# Verify firewall rule exists
netsh advfirewall firewall show rule name="RemoteKeyboard-8765"

# If missing, add manually (as Administrator):
netsh advfirewall firewall add rule name="RemoteKeyboard-8765" dir=in action=allow protocol=TCP localport=8765
```

**Check Port is Listening:**
```bash
netstat -ano | findstr :8765
# Should show: TCP 0.0.0.0:8765 LISTENING
```

**Test Connection:**
```bash
# From another device on same network:
telnet <PC-IP> 8765
# Or use PowerShell:
Test-NetConnection <PC-IP> -Port 8765
```

### APK Installation Fails

**Enable Unknown Sources:**
- Settings → Security → Unknown Sources (enable)
- Or Settings → Apps → Special Access → Install unknown apps

**Check Android Version:**
- Requires Android 10 or higher

### Build Errors

**PC Build Fails:**
```bash
# Update Rust
rustup update

# Clean and rebuild
cargo clean && cargo build --release
```

**Mobile Build Fails:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug --android-skip-build-dependency-validation
```

---

## 📊 Project Status

| Component | Status | Tests |
|-----------|--------|-------|
| PC - Domain Layer | ✅ Complete | 104 passing |
| PC - WebSocket Server | ✅ Complete | |
| PC - mDNS Discovery | ✅ Complete | |
| PC - Input Simulation | ✅ Complete | |
| PC - Firewall Config | ✅ Complete | |
| Mobile - Domain Layer | ✅ Complete | 61 passing |
| Mobile - WebSocket Client | ✅ Complete | |
| Mobile - Network Discovery | ✅ Complete | |
| Mobile - Touchpad UI | ✅ Complete | |
| Mobile - Keyboard UI | ✅ Complete | |
| Mobile - Media Keys UI | ✅ Complete | |

**Total Tests:** 165 passing ✅

---

## 🤝 Contributing

### How to Help

- Report bugs or feature requests
- Submit PRs (follow DDD architecture)
- Improve documentation
- Test on different devices/OS versions

### Development Guidelines

- Follow DDD layer structure
- Write tests for domain logic
- Update docs when changing architecture
- Keep transport layer abstracted

---

## 📝 License

MIT License - See LICENSE file for details.

---

## 🙏 Acknowledgments

- [enigo](https://github.com/enigo-rs/enigo) - Input simulation crate
- [Flutter](https://flutter.dev/) - Mobile app framework
- [mdns-sd](https://github.com/keepsimple1/mdns-sd) - mDNS library

---

*Last Updated: 2026-02-28*
*Version: 1.0.0*
*Builds: PC (3.3 MB) | Mobile APK (160 MB)*

```
RemoteKeyboard/
├── docs/                    # Documentation
│   ├── SPECIFICATION.md
│   ├── ARCHITECTURE.md
│   ├── PROTOCOL.md
│   ├── ROADMAP.md
│   └── DECISIONS.md
├── pc/                      # PC Application (Tauri + Rust)
│   ├── src/
│   │   ├── domain/          # Domain layer
│   │   ├── application/     # Application layer
│   │   ├── infrastructure/  # Infrastructure layer
│   │   ├── presentation/    # Tauri UI
│   │   └── main.rs
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   └── package.json
├── mobile/                  # Mobile Application (Flutter)
│   ├── lib/
│   │   ├── domain/          # Domain layer
│   │   ├── application/     # Application layer
│   │   ├── infrastructure/  # Infrastructure layer
│   │   ├── presentation/    # Flutter UI
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

---

## 📅 Development Status

**Current Phase:** Phase 1 Complete - PC Infrastructure Ready ✅

| Component | Phase | Status |
|-----------|-------|--------|
| PC - Domain Layer | 1 | ✅ Complete |
| PC - mDNS Discovery | 1 | ✅ Complete |
| PC - WebSocket Server | 1 | ✅ Complete |
| PC - Input Simulation | 1 | ✅ Complete |
| PC - Connection Manager | 1 | ✅ Complete |
| PC - Integration Tests | 1 | ✅ Complete (104 tests) |
| Mobile - Scaffolding | 2 | ✅ Complete |
| Mobile - Domain Layer | 2 | ⏳ In Progress |
| Mobile - WebSocket Client | 2 | ⏳ Pending |
| Mobile - mDNS Discovery | 2 | ⏳ Pending |
| Mobile - UI Implementation | 2 | ⏳ Pending |

See [ROADMAP.md](docs/ROADMAP.md) for detailed progress.

---

## 🎮 Usage (Future)

### PC Setup

1. Download and install RemoteKeyboard PC app
2. App runs in system tray
3. PC is automatically discoverable on LAN

### Mobile Setup

1. Install APK (Android) or IPA (iOS)
2. Open app, ensure same WiFi as PC
3. Tap discovered PC to connect
4. Use touchpad, keyboard, or media keys

---

## 🔧 Configuration

### PC (config.json)

```json
{
  "server": {
    "port": 8765,
    "host": "0.0.0.0"
  },
  "discovery": {
    "service_name": "_remotekeyboard._tcp",
    "instance_name": "LivingRoom-PC"
  }
}
```

### Mobile (Settings)

- Touchpad sensitivity
- Invert scroll direction
- Tap-to-click enable/disable
- Theme (dark/light)

---

## 🤝 Contributing

This is a personal project, but contributions are welcome!

### How to Help

- Report bugs or feature requests
- Submit PRs (follow DDD architecture)
- Improve documentation
- Test on different devices/OS versions

### Development Guidelines

- Follow DDD layer structure
- Write tests for domain logic
- Update docs when changing architecture
- Keep transport layer abstracted

---

## 📝 License

MIT License - See LICENSE file for details.

---

## 🙏 Acknowledgments

- [enigo](https://github.com/enigo-rs/enigo) - Input simulation crate
- [Tauri](https://tauri.app/) - Desktop app framework
- [Flutter](https://flutter.dev/) - Mobile app framework
- [mdns-sd](https://github.com/keepsimple1/mdns-sd) - mDNS library

---

*Last Updated: 2026-02-27*
*Version: 0.1.0 (Planning)*
