# Mobile App Setup Instructions

## Quick Start

### 1. Install Flutter

**Windows:**
```powershell
# Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
# Extract to C:\src\flutter

# Add to PATH
setx PATH "%PATH%;C:\src\flutter\bin"

# Restart terminal and verify
flutter doctor
```

**Install Android Studio:**
- Download: https://developer.android.com/studio
- Install Android SDK
- Run: `flutter doctor --android-licenses`

### 2. Setup Project

```bash
cd mobile

# Get dependencies
flutter pub get

# Generate JSON serialization code
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run the App

```bash
# Connect Android device via USB or start emulator
# Then run:
flutter run
```

---

## What's Been Created

### Project Structure ✅

```
mobile/
├── lib/
│   ├── main.dart                    ✅ App entry point
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── command.dart         ✅ Command types
│   │   │   ├── device.dart          ✅ Device entity
│   │   │   └── connection.dart      ✅ Connection entity
│   │   └── value_objects/
│   │       ├── mouse.dart           ✅ Mouse types
│   │       ├── keyboard.dart        ✅ Media types
│   │       └── device.dart          ✅ Device status
│   └── presentation/
│       ├── screens/
│       │   ├── home_screen.dart     ✅ Main navigation
│       │   ├── connection_screen.dart ✅ Device discovery
│       │   ├── touchpad_screen.dart  ✅ Touchpad UI
│       │   ├── keyboard_screen.dart  ✅ Keyboard UI
│       │   └── media_screen.dart     ✅ Media controls
│       └── theme/
│           └── app_theme.dart       ✅ App styling
├── android/
│   └── app/
│       ├── src/main/AndroidManifest.xml  ✅ Permissions
│       ├── src/main/kotlin/MainActivity.kt ✅ Entry point
│       └── build.gradle              ✅ Build config
├── test/
│   └── smoke_test.dart              ✅ Basic test
├── pubspec.yaml                     ✅ Dependencies
└── README.md                        ✅ Setup guide
```

### Features Implemented

**UI Screens:**
- ✅ Home screen with navigation
- ✅ Connection screen (device list)
- ✅ Touchpad screen (gesture area)
- ✅ Keyboard screen (text input + special keys)
- ✅ Media screen (playback controls)

**Domain Layer:**
- ✅ Command entity (mouse, keyboard, media)
- ✅ Device entity
- ✅ Connection entity
- ✅ Value objects

**Infrastructure (Pending):**
- ⏳ WebSocket client
- ⏳ mDNS discovery (requires native Android code)
- ⏳ State management (Riverpod providers)

---

## Next Steps

### Immediate (Required to Run)

1. **Install Flutter** (see above)
2. **Run setup commands:**
   ```bash
   cd mobile
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
3. **Test the UI:**
   ```bash
   flutter run
   ```

### Phase 2 Implementation

1. **WebSocket Client** (`lib/infrastructure/websocket/`)
   - Connect to PC WebSocket server
   - Send commands as JSON
   - Handle connection state

2. **State Management** (`lib/application/providers/`)
   - Connection state provider
   - Device discovery provider
   - Settings provider

3. **mDNS Discovery** (requires native Android)
   - Use platform channel or flutter_mdns plugin
   - Discover PCs on local network

4. **Integration**
   - Connect UI to providers
   - Test with PC server

---

## Testing Without Flutter (For Now)

You can review the code structure and UI design without installing Flutter:

1. **Review UI code:**
   - `lib/presentation/screens/home_screen.dart`
   - `lib/presentation/screens/touchpad_screen.dart`
   - `lib/presentation/screens/media_screen.dart`

2. **Review domain model:**
   - `lib/domain/entities/command.dart`
   - `lib/domain/entities/device.dart`

3. **Compare with PC implementation:**
   - PC domain: `pc/src/domain/`
   - Mobile domain: `mobile/lib/domain/`
   - Both follow same DDD structure

---

## Current Status

**What Works:**
- ✅ Project structure
- ✅ Domain layer (entities, value objects)
- ✅ UI screens (visual design)
- ✅ Android configuration

**What Needs Implementation:**
- ⏳ WebSocket client (connect to PC)
- ⏳ State management (Riverpod)
- ⏳ mDNS discovery (find PCs)
- ⏳ Integration tests

**Estimated Time to MVP:**
- WebSocket client: 2-3 hours
- State management: 2-3 hours
- mDNS discovery: 4-6 hours (native code)
- Integration: 2-3 hours
- **Total: ~10-15 hours**

---

## Questions?

See:
- `README.md` - Full project overview
- `docs/SPECIFICATION.md` - Requirements
- `docs/ARCHITECTURE.md` - System design
- `pc/README.md` - PC implementation details
