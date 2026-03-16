# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Build
xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" -configuration Debug build

# Bump version for the next release
./scripts/bump-version.sh patch  # or: minor, major

# Build a signed Developer ID release archive + notarization ZIP
bash scripts/sign-release.sh

# Optional local overrides live in .release.env (ignored by git)

# Notarize and staple the signed release app
# One-time setup:
# xcrun notarytool store-credentials "PtionsPlus" --apple-id "your@email.com" --team-id "YOUR_TEAM_ID" --password "app-specific-password"
bash scripts/notarize.sh

# Deploy the current built app to /Applications and restart
bash scripts/deploy.sh

# Reset config (forces fresh defaults)
rm -f ~/Library/Application\ Support/Ptions+/config.json
```

No tests exist yet. No linter configured.

## What This Is

**Ptions+** is a macOS menu bar app that intercepts extra mouse buttons (MX Master 4/3 family and others) via CGEventTap and triggers configurable keyboard shortcuts per-app. It replaces Logitech Options+ which doesn't work reliably.

The Xcode project is "PtionsPlus.xcodeproj", source folder is "PtionsPlus/", product name is "Ptions+".

## Architecture

**AppDelegate** owns all services and injects them into SwiftUI views. Lifecycle: AppDelegate creates services → starts ActiveAppMonitor → checks accessibility → starts EventTapService when trusted.

**Core event flow:** Mouse button press → `EventTapService` (CGEventTap callback) → looks up `MappingStore.profileFor(bundleIdentifier:)` using `ActiveAppMonitor.activeBundleIdentifier` → finds matching `ButtonMapping` → `KeySimulator.simulateShortcut()` → returns `nil` to suppress original mouse event.

**MappingStore** is a singleton (`MappingStore.shared`) with JSON persistence at `~/Library/Application Support/Ptions+/config.json`. Data model: `AppConfiguration` → `[AppProfile]` → `[ButtonMapping]` → `KeyboardShortcut?`. Profiles with `bundleIdentifier == nil` are the default fallback.

**ShortcutRecorderView** uses `NSViewRepresentable` wrapping a custom `NSView` that overrides both `keyDown` and `performKeyEquivalent` — necessary because SwiftUI intercepts modifier-key combinations. System shortcuts like Ctrl+↑ (Mission Control) can't be recorded; use `PresetShortcut` enum instead.

## Key Constraints

- **No App Sandbox** — CGEventTap and CGEvent posting require it. Entitlements explicitly set `com.apple.security.app-sandbox = false`.
- **Accessibility permission required** — `AXIsProcessTrusted()` must return true. AccessibilityChecker polls every 1s until granted.
- **LSUIElement = YES** — No dock icon, menu bar only.
- **macOS 13+ (Ventura)** — MenuBarExtra, SMAppService require it. Note: `Environment(\.openSettings)` is macOS 14+ only; we use `openWindow(id:)` instead.
- **Logi Options+ must be uninstalled** — Otherwise it captures the mouse buttons first.
- **System shortcuts can't be recorded** — macOS intercepts them before the app. Use `PresetShortcut` for Mission Control (⌃↑), App Exposé (⌃↓).

## MX Master 3 Button Numbers

| Button | Number | Notes |
|--------|--------|-------|
| Middle Click | 2 | otherMouseDown/Up |
| Back | 3 | otherMouseDown/Up |
| Forward | 4 | otherMouseDown/Up |
| Thumb/Gesture | 5 | Default: Mission Control |
| Button 6 | 6 | otherMouseDown/Up |
