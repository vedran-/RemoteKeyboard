# Architecture Decision Records (ADRs)

This document records all significant architectural decisions made for the RemoteKeyboard project.

---

## ADR-001: Use Flutter for Mobile Application

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need cross-platform mobile app (Android primary, iOS secondary)

### Decision

Use **Flutter (Dart)** for the mobile application.

### Rationale

**Pros:**
- Single codebase for Android + iOS
- Excellent touch/gesture handling (critical for touchpad)
- Hot reload for fast development
- Strong UI framework with Material Design
- Good performance (compiled to native ARM)

**Cons:**
- Larger APK size (~20MB baseline)
- iOS requires Mac for building (accepted constraint)

**Alternatives Considered:**
- **Kotlin + Swift native:** Best performance, but 2x development effort
- **React Native:** JavaScript bridge adds latency (concern for touchpad)
- **Jetpack Compose Multiplatform:** Less mature, iOS support experimental

### Consequences

- Need Flutter SDK installed for mobile development
- iOS development requires macOS (can be deferred)
- Dart language learning curve (minimal for experienced devs)

---

## ADR-002: Use Tauri + Rust for PC Application

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need lightweight PC app with system-level input access

### Decision

Use **Tauri (Rust backend + web frontend)** for the PC application.

### Rationale

**Pros:**
- Small binary size (~5MB vs ~100MB for Electron)
- Rust provides safe system access (enigo crate)
- Web technologies for UI (fast iteration)
- Built-in system tray support
- Strong security model

**Cons:**
- Tauri v2 is relatively new (but stable)
- Build tooling more complex than pure Rust

**Alternatives Considered:**
- **Pure Rust + native UI:** Too much boilerplate, UI is hard
- **Electron:** Too heavy (100MB+ RAM), overkill for this use case
- **.NET (WinUI/WPF):** Windows-only, limits future cross-platform
- **Python + tray:** Runtime dependency, slower, larger distribution

### Consequences

- Need Rust toolchain installed
- Need Node.js for Tauri frontend build
- Two languages in PC app (Rust + JS/TS)

---

## ADR-003: Use enigo Crate for Input Simulation

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need to simulate mouse/keyboard input on Windows

### Decision

Use the **enigo** crate (v0.1+) for input simulation on PC.

### Rationale

**Pros:**
- Most mature Rust crate for input simulation
- Cross-platform (Windows, macOS, Linux)
- Actively maintained
- Supports all required features:
  - Mouse move (relative + absolute)
  - Mouse clicks
  - Mouse scroll
  - Key press/release
  - Media keys
  - Text typing

**Cons:**
- Less control than direct Win32 API calls
- Potential limitations for advanced features (not yet identified)

**Alternatives Considered:**
- **Direct Win32 (SendInput via windows crate):** More control, but Windows-only and verbose
- **inputbot:** Windows-only, less maintained
- **rdev:** Good but more focused on event listening

### Contingency Plan

If enigo proves insufficient:
1. Extend with direct `windows` crate calls for specific features
2. Fork enigo and add needed features (upstream contribution)

### Consequences

- Dependency on enigo maintenance
- May need to contribute fixes upstream
- Should abstract behind InputExecutor trait (already planned)

---

## ADR-004: Use WebSocket (TCP) for Primary Transport

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need bidirectional real-time communication

### Decision

Use **WebSocket over TCP** as the primary transport protocol.

### Rationale

**Pros:**
- Bidirectional, full-duplex communication
- Built-in framing (no message boundary issues)
- Works through most firewalls
- Mature libraries on all platforms
- Reliable delivery (TCP guarantees)
- Low overhead (~2-14 bytes per frame)

**Cons:**
- TCP head-of-line blocking (minor for this use case)
- Slightly higher latency than raw UDP (acceptable)

**Why not UDP initially:**
- Touchpad events are small and frequent
- Lost mouse move doesn't matter (next one comes in 16ms)
- TCP reliability > UDP speed for control commands
- Simpler implementation (no reassembly, ordering, ack logic)

**Alternatives Considered:**
- **Raw TCP sockets:** Reinvent WebSocket framing
- **UDP:** Too much infrastructure needed (reliability, ordering)
- **gRPC:** Overkill, HTTP/2 complexity unnecessary
- **WebRTC:** P2P complexity, better for media streaming

### Future Extension

Architecture supports adding UDP later:
- Transport trait abstraction allows multiple implementations
- Can use TCP for commands, UDP for high-freq mouse
- No domain logic changes needed

### Consequences

- Need WebSocket library on both sides
- Need to handle connection drops gracefully
- Should implement heartbeat for connection health

---

## ADR-005: Use mDNS for Device Discovery

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need zero-config device discovery on LAN

### Decision

Use **mDNS (Multicast DNS)** per RFC 6762 for device discovery.

### Rationale

**Pros:**
- Zero configuration (no manual IP entry needed)
- Works on any LAN without internet
- Standard protocol (built into most OS)
- Service type registration (_remotekeyboard._tcp)
- Survives IP changes (DHCP)

**Cons:**
- May not work on all routers (some block mDNS)
- Slightly slower than hardcoded IP
- Can be noisy on network (periodic announcements)

**Alternatives Considered:**
- **Manual IP entry:** Always needed as fallback, poor UX as primary
- **Centralized discovery server:** Requires internet, adds dependency
- **Bluetooth discovery:** Slower, more complex pairing
- **QR code:** Requires camera, manual process

### Implementation

- PC: `mdns-sd` crate (Rust)
- Mobile: `flutter_mdns` or platform channel
- Service type: `_remotekeyboard._tcp`
- TXT records: version, name, protocol, path

### Fallback

Manual IP entry will be implemented as fallback for networks where mDNS fails.

### Consequences

- Need to handle mDNS failures gracefully
- Should provide manual IP entry option
- May need router-specific troubleshooting guide

---

## ADR-006: JSON over WebSocket for Message Format

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need serializable message format

### Decision

Use **JSON** for message serialization over WebSocket.

### Rationale

**Pros:**
- Human-readable (easy debugging)
- Extensible (add fields without breaking)
- Native support on all platforms
- Self-describing (field names included)
- Easy to prototype and iterate

**Cons:**
- Larger payload than binary (~2-3x)
- Parsing overhead (minor for small messages)
- No schema enforcement (runtime errors possible)

**Payload Size Analysis:**
```
Mouse move JSON: {"type":"mouse_move","payload":{"dx":10,"dy":-5},"timestamp":1709012345678}
Size: ~80 bytes
Binary equivalent: ~12 bytes
Overhead: ~68 bytes

At 60Hz: 68 bytes * 60 = 4 KB/s overhead
Impact: Negligible on LAN (100+ Mbps)
```

**Alternatives Considered:**
- **Protocol Buffers:** Smaller, faster, but needs schema, less flexible
- **MessagePack:** Binary, smaller, but harder to debug
- **CBOR:** Binary JSON, but less library support
- **Custom binary:** Maximum performance, but hard to extend and debug

### Future Optimization

If payload size becomes an issue:
1. Add optional MessagePack encoding (negotiated at handshake)
2. Compress large messages (type_text)
3. Use binary format for high-frequency mouse (if using UDP)

### Consequences

- Need JSON schema documentation (see PROTOCOL.md)
- Should validate payloads at runtime
- May need performance optimization later (profile first)

---

## ADR-007: Domain-Driven Design Architecture

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need maintainable, extensible codebase structure

### Decision

Use **Domain-Driven Design (DDD)** with layered architecture:
- Domain Layer (entities, value objects, domain services)
- Application Layer (use cases, ports)
- Infrastructure Layer (adapters)
- Presentation Layer (UI)

### Rationale

**Pros:**
- Clear separation of concerns
- Domain logic is testable without infrastructure
- Easy to swap infrastructure (e.g., add UDP transport)
- Aligns with user's stated preference
- Scales well as features grow

**Cons:**
- More boilerplate initially
- Learning curve for team unfamiliar with DDD
- May be overkill for very small projects (but this will grow)

**Alternatives Considered:**
- **Simple MVC:** Less structure, harder to extend
- **Clean Architecture:** Very similar, DDD is a good fit for this domain
- **Event Sourcing:** Overkill for this use case

### Layer Responsibilities

| Layer | Responsibility | Dependencies |
|-------|---------------|--------------|
| Domain | Business logic, entities, rules | None |
| Application | Use cases, orchestration | Domain |
| Infrastructure | External systems (network, input) | Domain, Application |
| Presentation | UI, user interaction | Application |

### Consequences

- More files and folders initially
- Need to enforce layer boundaries (code reviews)
- Dependency injection needed (use traits/interfaces)
- Unit tests can mock infrastructure

---

## ADR-008: Connection Model - Single Client First, Multi-Client Extensible

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need to define connection concurrency model

### Decision

**MVP (Phase 1-4):** Support **one active mobile connection at a time** (single-client model).

**Future (Phase 5+):** Support **multiple clients with arbitration** (configurable modes).

### Rationale

**Why single-client first:**
- Most common use case: one person controlling PC from couch
- Simpler state management, faster MVP
- Easier to test and debug
- Architecture already supports extension to multi-client

**Multi-client modes (future):**
| Mode | Description | Use Case |
|------|-------------|----------|
| Single | New client disconnects existing | Personal use |
| Broadcast | All clients control same cursor | Demo/presentation |
| Arbitration | Clients request/take turns | Shared living room |

### Behavior (MVP)

- When new client connects, existing client is disconnected with notification
- PC shows toast notification when connection changes
- Mobile shows "another device connected" error if rejected
- Config option to disable auto-disconnect (reject new connections)

### Architecture Readiness

Connection management is abstracted behind `ConnectionManager` service:

```rust
pub trait ConnectionManager: Send + Sync {
    fn accept_connection(&self, device: Device) -> Result<SessionId>;
    fn reject_connection(&self, device: Device, reason: String) -> Result<()>;
    fn disconnect_session(&self, session_id: SessionId) -> Result<()>;
    fn get_active_sessions(&self) -> Vec<Session>;
    // Future: add broadcast, arbitration modes
}
```

This allows changing from single-client to multi-client without refactoring domain logic.

### Consequences

- Need connection state tracking
- Need graceful disconnect of existing client
- Should log connection events
- Multi-client mode is additive (no breaking changes)

---

## ADR-009: Defer UDP to Future Phase

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Considering UDP for lower latency

### Decision

**Do not implement UDP in MVP.** Start with WebSocket (TCP) only. Add UDP later if latency profiling shows it's needed.

### Rationale

**Why defer:**
- TCP latency on LAN is typically <1ms (negligible)
- Touchpad at 60Hz over TCP is proven to work well (similar apps do this)
- UDP adds significant complexity:
  - Packet reassembly
  - Ordering guarantees
  - Reliability layer for commands
  - Firewall/NAT traversal issues
- Premature optimization without profiling data

**When to add UDP:**
- If profiling shows TCP latency >20ms on typical LAN
- If users report noticeable lag
- If we want 1000Hz mouse polling (gaming use case)

### Architecture Readiness

Transport abstraction (ADR-010) ensures UDP can be added without refactoring domain logic.

### Consequences

- Simpler MVP
- Clear performance baseline (measure TCP first)
- Future UDP work is additive, not replacing

---

## ADR-010: Transport Layer Abstraction

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need extensible communication layer

### Decision

Define a **Transport trait** that abstracts the communication mechanism. Domain layer depends on this trait, not concrete implementations.

```rust
pub trait Transport: Send + Sync {
    fn send(&self, command: &Command) -> Result<()>;
    fn listen(&self) -> BoxStream<Result<Command>>;
    fn connect(&self, device: &Device) -> Result<()>;
    fn disconnect(&self) -> Result<()>;
    fn is_connected(&self) -> bool;
}
```

### Rationale

**Pros:**
- Domain logic is transport-agnostic
- Can add UDP, Bluetooth, WebRTC without domain changes
- Easy to test with mock transport
- Supports hybrid transports (TCP + UDP)

**Cons:**
- Slight abstraction overhead
- Need to design interface carefully (may evolve)

### Implementation Strategy

1. Start with `WebSocketTransport` implementation
2. For future UDP, add `UdpTransport` implementation
3. Can create `HybridTransport` that uses both

### Consequences

- Need to ensure Command enum is transport-agnostic
- Should document transport requirements (ordering, reliability)
- May need to add transport-specific metadata later

---

## ADR-011: Windows 11 Primary, Cross-Platform Secondary

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need to define platform support priorities

### Decision

**Primary target:** Windows 11  
**Secondary targets:** Windows 10, macOS, Linux (in that order)

### Rationale

**Why Windows-first:**
- User requirement (PC connected to TV use case)
- Largest market share for this use case
- enigo has best Windows support
- Easier to test and debug

**Cross-platform path:**
- enigo supports macOS/Linux (same code)
- Tauri is cross-platform
- mDNS works on all platforms
- Should "just work" with minimal changes

### Consequences

- Develop and test on Windows 11
- Verify on Windows 10 before release
- macOS/Linux can be community-supported initially
- Document platform-specific setup (permissions, etc.)

---

## ADR-012: Comprehensive Documentation

**Date:** 2026-02-27  
**Status:** Accepted  
**Context:** Need maintainable project documentation

### Decision

Maintain **living documentation** in `docs/` folder:
- Updated as decisions are made
- Includes specs, architecture, protocol, roadmap
- Version-controlled with code
- Each document has "Last Updated" date

### Rationale

**Pros:**
- Knowledge doesn't live only in code
- Easier onboarding (for self or others)
- Decisions are traceable (ADRs)
- Progress is visible (ROADMAP)

**Cons:**
- Requires discipline to keep updated
- Documentation debt can accumulate

### Documentation Standards

- All docs in Markdown
- Include version and date
- Link between related docs
- Update docs before merging code that changes architecture

### Consequences

- Need to review docs in code review
- Should archive old ADRs (not delete)
- ROADMAP should reflect actual status

---

## Summary of Key Technologies

| Component | Technology | ADR |
|-----------|------------|-----|
| Mobile App | Flutter (Dart) | ADR-001 |
| PC App | Tauri + Rust | ADR-002 |
| Input Simulation | enigo crate | ADR-003 |
| Transport (Primary) | WebSocket (TCP) | ADR-004 |
| Discovery | mDNS | ADR-005 |
| Message Format | JSON | ADR-006 |
| Architecture | DDD (Layered) | ADR-007 |
| Connection Model | Single-client | ADR-008 |
| UDP | Deferred | ADR-009 |
| Transport Design | Trait abstraction | ADR-010 |
| Platform Priority | Windows 11 first | ADR-011 |
| Documentation | Living docs in docs/ | ADR-012 |

---

*Last Updated: 2026-02-27*
*Version: 1.0*
