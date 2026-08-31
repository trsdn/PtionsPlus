# CLAUDE.md

Repository guidance for Ptions+, a macOS 13+ menu bar app that maps extra mouse buttons to per-app keyboard shortcuts.

## Build, Test, and Release

```bash
# Debug build
xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Unit tests
xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" \
  -configuration Debug -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO test -only-testing:PtionsPlusTests

# UI smoke tests
xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" \
  -configuration Debug -destination "platform=macOS" \
  test -only-testing:PtionsPlusUITests

# Static analysis
xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO analyze

# Bump version, website metadata, and promote the changelog
./scripts/bump-version.sh patch  # or: minor, major

# Preview the release notes a tag would publish
scripts/changelog.sh release-notes v1.2.0

# Build signed archive, notarize/staple, and create verified ZIP/DMG
scripts/setup-notarization.sh --gui
bash scripts/sign-release.sh
bash scripts/notarize.sh

# Documentation and shell checks
bash scripts/check-documentation.sh
bash -n scripts/*.sh
```

Local release overrides live in `.release.env` and are ignored by git.

Release notes are not written by hand. Every user-facing change goes under `## Unreleased` in `CHANGELOG.md`,
`bump-version.sh` promotes those entries into a dated `## X.Y.Z` section, and the release workflow publishes that
section as the GitHub release body. A tag whose version has no changelog entries, or that leaves entries under
`## Unreleased`, fails before anything is signed.

## Architecture

`AppDelegate` owns the shared services and starts `ActiveAppMonitor`, lifetime Accessibility monitoring, and `RuntimeServiceCoordinator`.

Runtime invariant:

```text
configuration usable AND Enabled AND Accessibility trusted
    -> EventTapService running
otherwise
    -> EventTapService stopped and held synthetic input released
```

Core event flow:

```text
CGEventTap
  -> EventTapService translates the event
  -> HIDMouseDeviceService attributes it to a physical mouse
  -> EventStateMachine resolves the mapping and preserves down/up state per mouse
  -> SystemEventActionExecutor coordinates keyboard state or preset actions
  -> suppress or pass through using the original down-event decision
```

Important components:

- `MappingStore` publishes only configurations that were validated and atomically persisted.
- `ConfigurationRepository` distinguishes missing, corrupt, unsupported, invalid, and unwritable configuration states.
- `EventStateMachine` owns paired press state, keyed by device plus button, and held shortcut release.
- `KeyboardStateCoordinator` reference-counts overlapping keys and modifiers.
- `CoreDockClient` resolves the private Dock symbol dynamically; unavailable actions fail safely.
- `KeyboardLayoutResolver` maps logical preset characters through the active input source.
- `HotKeyCaptureTap` captures system-reserved shortcuts while recording and falls back to the responder chain.
- `HIDMouseDeviceService` discovers mice through IOKit and attributes button events to them.
- `LaunchAtLoginViewModel` uses `SMAppService.mainApp.status` as its source of truth.
- `ApplicationDiscoveryService` scans installed apps off the main thread and retains manual selection.

## Multiple Mice

`AppConfiguration` holds a shared scope (`mouseModel`, `profiles`, `globalButtons`) plus optional per-device
scopes in `devices`. Resolution rule:

```text
event device has a MouseDeviceConfiguration -> use that scope
otherwise                                   -> use the shared scope
```

- Devices are identified by vendor, product, and serial number, so configurations survive reconnects.
- Hardware without a serial number cannot be distinguished from an identical unit and shares one scope.
- Device discovery needs no extra permission; attribution needs Input Monitoring and degrades to the shared scope without it.
- `MappingStore.editingDeviceID` is UI state only. Runtime resolution always takes an explicit device id.

## Constraints

- The App Sandbox must remain disabled because global event interception and posting require Accessibility privileges.
- `LSUIElement = YES`; there is no Dock icon.
- macOS 13 is the deployment target.
- Logi Options+ or other software that captures the same buttons must be disabled.
- Mouse model selection is manual. Buttons outside the selected model remain saved but are inactive.
- Recorded custom shortcuts store physical key codes. Semantic presets resolve logical characters for the active keyboard layout.
- Spotlight, Notification Center, and space switching presets use the documented default macOS shortcut; users with reassigned shortcuts should record a custom shortcut.

## Persistence

Configuration is stored at:

```text
~/Library/Application Support/Ptions+/config.json
```

Never silently replace an unreadable file. Recovery actions create a timestamped backup before repair or reset.

## MX Master 3 Button Numbers

| Button | Number |
|--------|--------|
| Middle Click | 2 |
| Back | 3 |
| Forward | 4 |
| Thumb/Gesture | 5 |
