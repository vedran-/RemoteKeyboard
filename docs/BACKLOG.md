# RemoteKeyboard - Feature Backlog

**Last Updated:** 2026-03-01
**Status:** MVP Complete ✅
**Total Features:** 47 planned
**Completed:** 13 features
**Remaining:** 34 features

---

## ✅ Recently Completed

### Auto-Reconnect & Smart Features (2026-03-01)
- ✅ Heartbeat Mechanism
- ✅ Auto-Reconnect with exponential backoff
- ✅ Cold Start Reconnect to last PC
- ✅ Connection Preferences (SharedPreferences)
- ✅ Android Network Permissions (critical bug fix!)
- ✅ Notification System (dismissible, auto-dismiss)
- ✅ Integration Test Framework
- ✅ 28 Integration Tests

---

## 🎯 How to Use This Document

This document tracks all planned features for RemoteKeyboard. Use it to:

- **Track Progress** - Check off completed features
- **Prioritize** - Focus on High priority items first
- **Plan Releases** - Group features by milestone

**Status Legend:**
- 🔴 High Priority
- 🟡 Medium Priority
- 🟢 Low Priority
- ⚪ Future/Experimental
- ✅ Complete

---

## Phase 1: Connection Reliability 🔧

*Critical improvements to connection stability and user experience*

### Heartbeat & Auto-Reconnect

- [ ] **#1 Heartbeat Mechanism** 🔴
  - PC sends heartbeat every 5 seconds
  - Mobile acknowledges with heartbeat_ack
  - Detect dead connections within 15 seconds
  - **Effort:** Medium | **Impact:** High

- [ ] **#2 Auto-Reconnect** 🔴
  - Automatically retry connection when dropped
  - Exponential backoff: 1s → 2s → 4s → 8s → 30s (max)
  - Show "Reconnecting..." status to user
  - Cancel on user action
  - **Effort:** Medium | **Impact:** High

- [ ] **#3 Reconnect to Last PC on Cold Start** 🔴 *(NEW)*
  - Save last connected PC (IP, port, name) to SharedPreferences
  - On app cold start, automatically attempt reconnection
  - Show "Reconnecting to [PC Name]..." overlay
  - Timeout after 10s, show connect screen
  - User can cancel reconnection
  - **Effort:** Medium | **Impact:** High

### Connection Quality

- [ ] **#4 Connection Timeout Handling** 🔴
  - Proper timeout detection (< 5s)
  - User-friendly error messages
  - Troubleshooting hints (check firewall, WiFi, etc.)
  - **Effort:** Low | **Impact:** High

- [ ] **#5 Better Error Messages** 🟡
  - Replace technical errors with user-friendly text
  - Categorize errors (network, firewall, server offline)
  - Suggest fixes for each error type
  - **Effort:** Low | **Impact:** Medium

- [ ] **#6 Connection Survives Sleep/Wake** 🟡
  - Detect PC sleep/wake events
  - Automatically reconnect after wake
  - Handle mobile device sleep similarly
  - **Effort:** Medium | **Impact:** Medium

---

## Phase 2: Mobile UX Improvements 📱

*Enhance mobile app usability and polish*

### Notifications (CRITICAL FIX)

- [ ] **#7 Single Active Notification** 🔴 *(NEW)*
  - New notification dismisses previous one immediately
  - No stacking or queuing
  - **Effort:** Low | **Impact:** High

- [ ] **#8 Dismissible Notifications** 🔴 *(NEW)*
  - Swipe-to-dismiss or tap-to-close
  - Don't block interactive elements
  - **Effort:** Low | **Impact:** High

- [ ] **#9 Smart Notification Timing** 🔴 *(NEW)*
  - Connection status: 3s (dismissible)
  - Command confirmations: 1s (auto-dismiss)
  - Errors: 5s (dismissible)
  - Critical errors: Persistent until acknowledged
  - **Effort:** Low | **Impact:** High

### Settings & Preferences

- [ ] **#10 Settings Screen** 🔴
  - Touchpad sensitivity (persisted)
  - Invert scroll direction
  - Tap-to-click toggle
  - Theme selection (dark/light/system)
  - **Effort:** Medium | **Impact:** High

- [ ] **#11 Sensitivity Persistence** 🟡
  - Save touchpad sensitivity between sessions
  - Per-device settings (optional)
  - **Effort:** Low | **Impact:** Medium

- [ ] **#12 Theme Customization** 🟢
  - Dark mode
  - Light mode
  - System default
  - **Effort:** Low | **Impact:** Low

### Connection Management

- [ ] **#13 Connection History** 🟢
  - Remember last 5 PCs
  - Quick reconnect from history
  - Remove from history option
  - **Effort:** Low | **Impact:** Medium

- [ ] **#14 Quick Connect Widget (Android)** ⚪
  - Home screen widget
  - One-tap reconnect to last PC
  - **Effort:** Medium | **Impact:** Low

---

## Phase 3: PC Enhancements 🖥️

*Improve PC server functionality and usability*

### System Integration

- [ ] **#15 System Tray Icon** 🔴
  - Icon in system tray
  - Right-click menu: Status, Quit, Settings
  - Double-click to show status window
  - **Effort:** Medium | **Impact:** High

- [ ] **#16 Auto-Start on Boot** 🟡
  - Optional: start server on Windows boot
  - Configurable in settings
  - **Effort:** Low | **Impact:** Medium

### Server Features

- [ ] **#17 Multiple Client Support** 🟢
  - Allow 2+ phones to connect simultaneously
  - Broadcast mode (all control same cursor)
  - Optional: arbitration mode (take turns)
  - **Effort:** Medium | **Impact:** Low

- [ ] **#18 Connection Whitelist** 🟢
  - Security feature
  - Only allow specific device IDs/IPs
  - Config file based
  - **Effort:** Low | **Impact:** Low

- [ ] **#19 Server Config File** 🟢
  - JSON config: port, instance name, etc.
  - Auto-generated on first run
  - **Effort:** Low | **Impact:** Low

---

## Phase 4: Platform Expansion 🌍

*Support more platforms and optimize existing ones*

### New Platforms

- [ ] **#20 iOS App** 🟡
  - Full iOS client
  - Requires macOS build environment
  - App Store distribution
  - **Effort:** Very High | **Impact:** High

- [ ] **#21 macOS PC Support** 🟢
  - Server runs on macOS
  - enigo supports macOS
  - Test input simulation
  - **Effort:** Low | **Impact:** Low

- [ ] **#22 Linux PC Support** 🟢
  - Server runs on Linux
  - enigo supports Linux
  - Test input simulation
  - **Effort:** Low | **Impact:** Low

### Optimization

- [ ] **#23 Android APK Size Reduction** 🟡
  - Current: 160 MB → Target: 50 MB
  - Split per ABI (already done)
  - Remove unused dependencies
  - **Effort:** Medium | **Impact:** Medium

- [ ] **#24 Mobile Background Service** 🟢
  - Keep connection alive when app backgrounded
  - Foreground service (Android)
  - Background mode (iOS)
  - **Effort:** Medium | **Impact:** Medium

---

## Phase 5: Advanced Features ✨

*Power-user features and enhancements*

### Input Enhancements

- [ ] **#25 Haptic Feedback** 🟡
  - Vibration on button press
  - Configurable intensity
  - **Effort:** Low | **Impact:** Medium

- [ ] **#26 Custom Key Bindings** 🟢
  - User-configurable button mappings
  - Preset layouts (gaming, media, etc.)
  - **Effort:** Medium | **Impact:** Low

- [ ] **#27 Macro Recording/Playback** ⚪
  - Record keyboard/mouse sequences
  - Playback on demand
  - Store on PC or mobile
  - **Effort:** High | **Impact:** Low

### Media & File Features

- [ ] **#28 Screen Mirroring** ⚪
  - Stream PC screen to mobile
  - Low-latency codec (H.264)
  - Touch controls overlaid
  - **Effort:** Very High | **Impact:** Medium

- [ ] **#29 File Transfer** ⚪
  - Transfer files between PC and mobile
  - Drag-drop interface
  - **Effort:** High | **Impact:** Low

- [ ] **#30 Voice Input** ⚪
  - Voice-to-text on PC
  - Voice commands ("click", "scroll", etc.)
  - **Effort:** High | **Impact:** Low

---

## Phase 6: Distribution & Production 📦

*Prepare for public release*

### Code Quality & Security

- [ ] **#31 Code Signing (Windows)** 🔴
  - Sign executables
  - Avoid SmartScreen warnings
  - Purchase code signing certificate
  - **Effort:** Low (cost: $) | **Impact:** High

- [ ] **#32 Auto-Update Mechanism** 🟡
  - Check for updates on startup
  - Download and install silently
  - Restart to apply
  - **Effort:** High | **Impact:** High

### Store Releases

- [ ] **#33 Google Play Store Release** 🟡
  - Prepare store listing
  - Screenshots, description
  - Comply with Play policies
  - **Effort:** Medium | **Impact:** High

- [ ] **#34 Microsoft Store Release** 🟢
  - Package as MSIX
  - Submit to Microsoft Store
  - **Effort:** Medium | **Impact:** Medium

- [ ] **#35 MSI Installer (PC)** 🟡
  - Professional installer
  - Silent install option
  - Add/remove programs entry
  - **Effort:** Low | **Impact:** Medium

---

## Phase 7: Future Technologies 🚀

*Experimental and long-term features*

### Transport Layer

- [ ] **#36 UDP Transport** ⚪
  - Lower latency for high-frequency mouse
  - ADR-009: Deferred to future phase
  - **Effort:** High | **Impact:** Medium

- [ ] **#37 Hybrid Transport** ⚪
  - TCP for commands (reliable)
  - UDP for mouse (fast)
  - ADR-010: Architecture ready
  - **Effort:** Very High | **Impact:** Medium

### Remote Access

- [ ] **#38 Remote Connection (WAN)** ⚪
  - Connect outside LAN
  - Relay server or port forwarding
  - Security: authentication, encryption
  - **Effort:** Very High | **Impact:** High

- [ ] **#39 Cloud Sync** ⚪
  - Sync settings across devices
  - User accounts
  - **Effort:** Medium | **Impact:** Low

### Discovery

- [ ] **#40 Bluetooth Discovery** ⚪
  - Alternative to mDNS
  - Pairing-based
  - **Effort:** Medium | **Impact:** Low

---

## Phase 8: Technical Debt 🔨

*Improve code quality and maintainability*

### Testing

- [ ] **#41 Integration Test Suite** 🟡
  - Automated integration tests
  - Mock WebSocket, mDNS
  - **Effort:** Medium | **Impact:** Medium

- [ ] **#42 E2E Test Automation** 🟢
  - Full end-to-end scenarios
  - CI integration
  - **Effort:** High | **Impact:** Medium

- [ ] **#43 Test Coverage >80%** 🟢
  - Current: ~60%
  - Target: 80%
  - **Effort:** Medium | **Impact:** Medium

### Documentation

- [ ] **#44 Documentation Site** ⚪
  - GitBook or similar
  - User guides
  - Troubleshooting
  - **Effort:** Medium | **Impact:** Low

### Performance

- [ ] **#45 Performance Profiling** 🟢
  - Identify bottlenecks
  - Optimize critical paths
  - Target: <30ms latency
  - **Effort:** Medium | **Impact:** Medium

---

## Summary by Priority

### 🔴 High Priority (Next Release v1.1.0)

1. Heartbeat Mechanism
2. Auto-Reconnect
3. Reconnect to Last PC on Cold Start
4. Connection Timeout Handling
5. Single Active Notification
6. Dismissible Notifications
7. Smart Notification Timing
8. Settings Screen
9. System Tray Icon
10. Code Signing (Windows)

**Total:** 10 features

### 🟡 Medium Priority (Release v1.2.0)

1. Better Error Messages
2. Connection Survives Sleep/Wake
3. iOS App
4. Android APK Size Reduction
5. Auto-Start on Boot
6. Haptic Feedback
7. Auto-Update Mechanism
8. Google Play Store Release
9. MSI Installer
10. Integration Test Suite

**Total:** 10 features

### 🟢 Low Priority (Release v1.3.0)

1. Theme Customization
2. Connection History
3. Multiple Client Support
4. Connection Whitelist
5. Server Config File
6. macOS PC Support
7. Linux PC Support
8. Mobile Background Service
9. Custom Key Bindings
10. Microsoft Store Release
11. E2E Test Automation
12. Test Coverage >80%
13. Performance Profiling

**Total:** 13 features

### ⚪ Future/Experimental (v2.0.0+)

1. Quick Connect Widget
2. Macro Recording/Playback
3. Screen Mirroring
4. File Transfer
5. Voice Input
6. UDP Transport
7. Hybrid Transport
8. Remote Connection (WAN)
9. Cloud Sync
10. Bluetooth Discovery
11. Documentation Site

**Total:** 11 features

---

## Release History

### v1.0.0 (2026-03-01) - MVP Complete ✅

**Shipped Features:**
- ✅ PC Server (WebSocket + mDNS + Input simulation)
- ✅ Mobile Client (Windows + Android)
- ✅ Touchpad, Keyboard, Media Keys
- ✅ Network discovery
- ✅ Firewall auto-configuration
- ✅ GitHub Actions CI/CD
- ✅ 165 tests passing

---

## Feature Request Template

**For new feature requests, use this template:**

```markdown
### Feature Name

**Priority:** High/Medium/Low/Experimental

**Description:**
What does this feature do?

**User Benefit:**
Why do users need this?

**Technical Complexity:**
Low/Medium/High/Very High

**Dependencies:**
Does this depend on other features?

**Estimated Effort:**
Days/weeks to implement
```

---

*This is a living document. Update it as features are completed or priorities change.*
