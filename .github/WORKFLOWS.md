# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated builds and releases.

## Workflows

### 1. CI (`ci.yml`)

**Purpose:** Build on every push and PR to catch errors early.

**Triggers:**
- Push to `main`, `master`, `develop` branches
- Pull requests to these branches

**Builds:**
- PC Server (Windows) - Rust
- Mobile Client (Windows) - Flutter

**Artifacts:** None (build verification only)

---

### 2. Release (`release.yml`)

**Purpose:** Create GitHub Releases with downloadable build artifacts.

**Triggers:**
- Git tags matching `v*.*.*` (e.g., `v1.0.0`, `v2.1.3`)

**Builds:**
- PC Server (Windows) → `RemoteKeyboard-Server-v{version}.exe`
- Mobile Client (Windows) → `RemoteKeyboard-Client-v{version}.exe`

**Release:**
- Creates draft release on GitHub
- Attaches both EXE files
- Auto-generates release notes from commits

---

### 3. Mobile Android (`mobile-android.yml`)

**Purpose:** Build Android APKs for releases.

**Triggers:**
- Git tags matching `v*.*.*` (automatic)
- Manual trigger from Actions tab (on-demand)

**Builds:**
- Android APK (universal) → `RemoteKeyboard-Client-v{version}.apk`
- Android APK (ARM64) → `RemoteKeyboard-Client-v{version}-arm64.apk`
- Android APK (ARMv7) → `RemoteKeyboard-Client-v{version}-armv7.apk`

**Release:**
- Uploads APKs to existing GitHub Release
- Runs after `release.yml` creates the release

---

## How to Create a Release

### Step 1: Ensure Everything Builds

```bash
# Run tests locally
cd pc && cargo test
cd mobile && flutter test

# Build locally
cd pc && cargo build --release
cd mobile && flutter build windows --release
cd mobile && flutter build apk --release
```

### Step 2: Create and Push Tag

```bash
# Create tag (use semantic versioning)
git tag v1.0.0

# Push tag to GitHub
git push origin v1.0.0
```

### Step 3: Monitor Build

1. Go to **Actions** tab on GitHub
2. Click on the release workflow run (e.g., "Release v1.0.0")
3. Wait for all jobs to complete (~10-15 minutes)

### Step 4: Publish Release

1. Go to **Releases** on GitHub
2. Find the draft release (e.g., "Draft release v1.0.0")
3. Add release notes describing what's new
4. Click **Publish release**

---

## Build Outputs

### PC Server (Windows)

**Location:** `pc/target/release/RemoteKeyboard-Server-v{version}.exe`
**Size:** ~3.3 MB
**Requirements:** Windows 10/11, .NET not required

### Mobile Client (Windows)

**Location:** `mobile/build/windows/x64/runner/Release/RemoteKeyboard-Client-v{version}.exe`
**Size:** ~30 MB
**Requirements:** Windows 10/11

### Mobile Client (Android)

**Locations:**
- `RemoteKeyboard-Client-v{version}.apk` (universal, ~160 MB)
- `RemoteKeyboard-Client-v{version}-arm64.apk` (ARM64 devices, ~50 MB)
- `RemoteKeyboard-Client-v{version}-armv7.apk` (ARMv7 devices, ~50 MB)

**Requirements:** Android 10+

---

## Troubleshooting

### Build Fails on GitHub

1. Click on the failed workflow run
2. Expand the failed job
3. Read the error logs
4. Fix the issue locally
5. Push fix and create new tag (e.g., `v1.0.1`)

### Release Not Created

- Check if tag was pushed: `git push origin v1.0.0`
- Verify tag format: must be `v*.*.*` (e.g., `v1.0.0`, not `1.0.0`)
- Check Actions tab for workflow errors

### APK Build Fails

- Ensure Android SDK is configured in Flutter
- Check `mobile/android/local.properties` exists
- Verify `minSdkVersion` in `android/app/build.gradle`

---

## Cost Optimization

GitHub Actions has free tier limits:
- **Public repos:** 2,000 minutes/month (free)
- **Private repos:** 500 MB storage + limited minutes

**Optimization tips:**
1. Android builds run on Ubuntu (faster, cheaper than Windows)
2. CI only builds on push/PR (not every commit to feature branches)
3. Artifacts retained for 30 days (configurable)

---

## Adding New Platforms

To add a new platform (e.g., macOS, Linux, iOS):

1. Create new workflow file or add job to existing workflow
2. Follow naming convention: `RemoteKeyboard-{Server|Client}-{platform}-v{version}.{ext}`
3. Add artifact upload step
4. Update release workflow to include new artifact

Example for macOS:
```yaml
build-macos:
  runs-on: macos-latest
  steps:
    # ... build steps ...
  - name: Upload artifact
    uses: actions/upload-artifact@v4
    with:
      name: macos-client
      path: RemoteKeyboard-Client-macos-v${{ github.ref_name }}.dmg
```

---

*Last Updated: 2026-03-01*
*Version: 1.0*
