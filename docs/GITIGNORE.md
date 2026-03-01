# Git Ignore Configuration

This document describes the `.gitignore` configuration for the RemoteKeyboard project.

## File Structure

```
RemoteKeyboard/
├── .gitignore              # Global ignores (root level)
├── pc/
│   └── .gitignore          # Rust/Tauri specific ignores
└── mobile/
    └── .gitignore          # Flutter specific ignores
```

## What's Ignored

### Global (.gitignore)

- **Build outputs**: `/build/`, `/target/`, `**/build/`, `**/target/`
- **IDE files**: `.idea/`, `.vscode/`, `*.iml`, `*.ipr`, `*.iws`
- **OS files**: `.DS_Store`, `Thumbs.db`, `desktop.ini`
- **Logs**: `*.log`, `logs/`
- **Environment**: `.env`, `.env.local`
- **Temp files**: `/tmp/`, `*.tmp`, `*.bak`
- **Test coverage**: `/coverage/`, `*.lcov`
- **Secrets**: `*.pem`, `*.key`, `*.jks`, `*.keystore`
- **Large binaries**: `*.mp4`, `*.iso`, `*.zip`

### PC Application (pc/.gitignore)

- **Rust build**: `/target/`, `**/target/`
- **Tauri generated**: `/gen/`, `/icons/`
- **Node modules**: `/node_modules/`
- **Profiling**: `*.profraw`, `*.profdata`

### Mobile Application (mobile/.gitignore)

- **Flutter build**: `/.dart_tool/`, `/build/`, `/.pub-cache/`
- **Plugin files**: `.flutter-plugins`, `.flutter-plugins-dependencies`
- **Android**: `/android/app/debug/`, `/android/.gradle/`, `local.properties`
- **iOS**: `/ios/Pods/`, `/ios/Flutter/Generated.xcconfig`
- **Platform ephemeral**: `**/ephemeral/`

## What's Tracked

### ✅ Should Be Committed

- Source code: `*.dart`, `*.rs`, `*.html`, `*.css`, `*.js`
- Configuration: `pubspec.yaml`, `Cargo.toml`, `tauri.conf.json`
- Documentation: `*.md` in `/docs/` and root
- Build scripts: `build.rs`, `build_run.bat`
- Assets: Images, icons (source files)

### ❌ Should NOT Be Committed

- Build artifacts (see above)
- IDE settings (unless team-shared)
- Environment files with secrets
- Generated code (`*.g.dart` is OK if source-controlled)
- Platform-specific generated files

## Verification

To check what would be ignored:

```bash
# See what git sees
git status --short

# Test specific file
git check-ignore -v <path-to-file>
```

## Notes

1. **Cargo.lock**: Currently ignored for binaries (default Rust behavior). Uncomment in `pc/.gitignore` if building a library.

2. **VS Code settings**: `.vscode/` is ignored by default. Uncomment in global `.gitignore` if you want to share team settings.

3. **Generated code**: `*.g.dart` files from `json_serializable` are committed (they're part of the source).

4. **Gradle wrapper**: The gradle wrapper JAR is NOT ignored (it's needed for builds).

---

*Last Updated: 2026-03-01*
*Version: 1.0*
