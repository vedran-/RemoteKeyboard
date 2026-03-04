# Optimization Plan: RemoteKeyboard Screen Streaming & Protocol

## Research
- [x] Read documentation and analyze all source code

## Implementation
### Phase 1: Server Protocol Rewrite
- [x] 1.1 New message types in [command.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/domain/entities/command.rs) (flat JSON)
- [x] 1.2 Rewrite message handling in [server.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/websocket/server.rs) (binary WS, ping/pong)
- [x] 1.3 Remove base64 from [screen_capture.rs](file:///c:/pj/projects/LLM/RemoteKeyboard/pc/src/infrastructure/screen_capture.rs)

### Phase 2: Persistent Capture Session
- [/] 2.1 New `CaptureManager` module
- [ ] 2.2 Fix monitor enumeration (`EnumDisplayMonitors` + logical math)
- [ ] 2.3 Incremental frames (check for changes)

### Phase 3: Client Protocol Rewrite
- [ ] 3.1 Update `command.dart` (flat JSON)
- [ ] 3.2 Handle binary frames in [websocket_client.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/infrastructure/websocket/websocket_client.dart)
- [ ] 3.3 Update [screen_stream_service.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/application/services/screen_stream_service.dart)
- [ ] 3.4 Streaming lifecycle in [home_screen.dart](file:///c:/pj/projects/LLM/RemoteKeyboard/mobile/lib/presentation/screens/home_screen.dart)

### Phase 4: Pixel Operation Optimizations
- [ ] Bulk canvas clear, bulk swizzle, bulk slice copy

### Phase 5: Reduce Logging
- [ ] Server log sweep
- [ ] Client log sweep

## Verification
- [ ] Run test suite
- [ ] Manual test streaming start/stop
