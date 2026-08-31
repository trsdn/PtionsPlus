# AGENTS.md

Authoritative instructions for automated agents and contributors working in
this repository. Tool-specific configuration files must reference this document
rather than restate it.

## Purpose

Ptions+ is a native macOS 13+ menu bar app that maps extra mouse buttons to
per-app keyboard shortcuts. It is an open-source replacement for vendor mouse
companion software. Written in Swift and SwiftUI, no third-party dependencies.

Primary language for all user-facing strings, code, comments, commits, issues,
and documentation is **English**.

## Layout

```text
PtionsPlus/            App source
  PtionsApp.swift        Entry point, AppDelegate, lifecycle
  Model/                 Data models and persistence
  Services/              Event tap, state machine, key simulation, runtime
  Views/                 SwiftUI menu bar, settings, editors
  Utilities/             Key code map, constants, product identity
PtionsPlusTests/       Unit tests
PtionsPlusUITests/     UI smoke tests
docs/                  Published site (GitHub Pages, main branch, /docs)
scripts/               Build, release, and validation scripts
plan/                  Architecture planning notes
```

## Commands

Run everything from the repository root.

### Validate a change

One command covers build, tests, static analysis, formatting, documentation
consistency, and shell syntax. Run it before proposing any change.

```bash
scripts/validate.sh
```

Pass `--fast` to skip the UI smoke tests and the release build when iterating.

### Individual commands

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

# Formatting check (and `--fix` to apply)
scripts/lint.sh

# Documentation and shell checks
bash scripts/check-documentation.sh
bash -n scripts/*.sh
```

### Release

Releases run from a `v*` tag through `.github/workflows/release.yml`. See
[`README.md`](README.md#signed-release-build) for the local equivalent. Do not
run these unattended; see [High-risk operations](#high-risk-operations).

```bash
./scripts/bump-version.sh patch   # or: minor, major
bash scripts/sign-release.sh
bash scripts/notarize.sh
```

## High-risk operations

Never perform any of the following without an explicit, specific instruction
from a maintainer in the current task.

**Version control**

- Do not rewrite history on `main` or any published branch.
- Do not force-push to any branch, and never to `main`.
- Do not create, move, or delete `v*` tags. A tag triggers a signed, notarized,
  public release.
- Do not push directly to `main`; it is protected and requires a pull request
  with passing checks.

**Secrets and signing**

- Never commit `.release.env`, signing certificates, provisioning profiles,
  keychain contents, Apple ID credentials, app-specific passwords, or
  notarization profiles. `.release.env` is gitignored and must stay that way.
- Never echo, log, or paste the values of `MACOS_CERTIFICATE`,
  `MACOS_CERTIFICATE_PWD`, `APPLE_ID`, `APPLE_TEAM_ID`, or
  `APPLE_APP_PASSWORD`.
- Do not modify keychain state outside `scripts/sign-release.sh` and the
  release workflow, which create and delete a temporary keychain.

**Release and deployment**

- Do not run `scripts/sign-release.sh`, `scripts/notarize.sh`, or
  `scripts/deploy.sh` unattended. They sign, notarize, and install artifacts.
- Do not publish, edit, or delete GitHub releases or their assets.
- Do not change GitHub Pages settings; the site publishes from `main` at
  `/docs`.

**User data**

- Never delete or hand-edit `~/Library/Application Support/Ptions+/config.json`
  on a real machine. It is user data. Tests must use a temporary directory.
- Never weaken the atomic, validated write path in
  `ConfigurationPersistence`. A corrupt configuration is preserved and backed
  up, never silently replaced.

**Destructive shell**

- No recursive deletes outside the repository working tree, `build/`, and
  `dist/`.
- No `git clean -x` in a worktree that may hold local release configuration.

## Machine-owned paths

Generated or tool-owned. Do not hand-edit.

| Path | Owner |
|---|---|
| `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `PtionsPlus.xcodeproj/project.pbxproj` | `scripts/bump-version.sh` |
| `PtionsPlus/Utilities/ProductIdentity.swift` version constants | Derived from the bundle at runtime; values come from the build |
| `"softwareVersion"` and the version badge in `docs/index.html` | `scripts/bump-version.sh` |
| `docs/assets/core.tokens.css`, `docs/assets/instrument-workshop.css`, `docs/assets/instrument-workshop-fonts.css`, `docs/assets/fonts/**` | Vendored from `trsdn/design-system`. Re-vendor from a tag; never patch in place. |
| `.github/badges/*.svg` | Generated from `.github/conformance.yml` and the stats workflow |
| `build/`, `dist/`, `TestResults/` | Build output, gitignored |

## Attribution and review

- Agent-authored commits carry a `Co-authored-by` trailer naming the agent.
- Every change reaches `main` through a pull request. `main` requires the
  `Build, analyze, and unit tests` and `UI smoke tests` checks to pass, the
  branch to be current, and conversations to be resolved.
- A human maintainer reviews and merges. Agents do not self-merge.

## Constraints

These are product invariants. Changing one requires an explicit decision, not a
refactor.

- The App Sandbox stays **disabled**. Global event interception and posting
  require Accessibility privileges, which the sandbox forbids.
- `LSUIElement = YES`. There is no Dock icon, and no change may introduce one.
- macOS 13 is the deployment target.
- Runtime invariant:

  ```text
  configuration usable AND Enabled AND Accessibility trusted
      -> EventTapService running
  otherwise
      -> EventTapService stopped and held synthetic input released
  ```

- Recorded custom shortcuts store physical key codes. Semantic presets resolve
  logical characters through the active keyboard layout.
- Spotlight, Notification Center, and space-switching presets use the documented
  default macOS shortcut. A user who reassigned those should record a custom
  shortcut.
- Mouse model selection is manual. Buttons outside the selected model stay
  saved but inactive.
- Ptions+ makes no network requests and collects no data. Do not add telemetry,
  analytics, crash reporting, or update checks.
- The published site loads no third-party resources, sets no cookies, and
  carries no analytics. Do not add a remote font, script, or image host.

## Architecture

`AppDelegate` owns the shared services and starts `ActiveAppMonitor`, lifetime
Accessibility monitoring, and `RuntimeServiceCoordinator`.

```text
CGEventTap
  -> EventTapService translates the event
  -> HIDMouseDeviceService attributes it to a physical mouse
  -> EventStateMachine resolves the mapping and preserves down/up state per mouse
  -> SystemEventActionExecutor coordinates keyboard state or preset actions
  -> suppress or pass through using the original down-event decision
```

- `MappingStore` publishes only configurations that were validated and
  atomically persisted.
- `ConfigurationRepository` distinguishes missing, corrupt, unsupported,
  invalid, and unwritable configuration states.
- `EventStateMachine` owns paired press state, keyed by device plus button, and
  held shortcut release.
- `KeyboardStateCoordinator` reference-counts overlapping keys and modifiers.
- `CoreDockClient` resolves the private Dock symbol dynamically; unavailable
  actions fail safely.
- `KeyboardLayoutResolver` maps logical preset characters through the active
  input source.
- `HotKeyCaptureTap` captures system-reserved shortcuts while recording and
  falls back to the responder chain.
- `HIDMouseDeviceService` discovers mice through IOKit and attributes button
  events to them.
- `LaunchAtLoginViewModel` uses `SMAppService.mainApp.status` as its source of
  truth.
- `ApplicationDiscoveryService` scans installed apps off the main thread and
  retains manual selection.

### Multiple mice

`AppConfiguration` holds a shared scope (`mouseModel`, `profiles`,
`globalButtons`) plus optional per-device scopes in `devices`. Resolution rule:

```text
event device has a MouseDeviceConfiguration -> use that scope
otherwise                                   -> use the shared scope
```

- Devices are identified by vendor, product, and serial number, so
  configurations survive reconnects.
- Hardware without a serial number cannot be distinguished from an identical
  unit and shares one scope.
- Device discovery needs no extra permission; attribution needs Input
  Monitoring and degrades to the shared scope without it.
- `MappingStore.editingDeviceID` is UI state only. Runtime resolution always
  takes an explicit device id.

## Logging

The app logs through `os.Logger` under the subsystem `com.torsten.Ptions-Plus`,
which is the bundle identifier.

Logs must stay actionable without leaking user data. Never log:

- the contents of `config.json` or any mapping payload;
- key codes or modifier flags captured from real user input outside the
  explicit Debug monitor, which is user-initiated, bounded, and never persisted;
- bundle identifiers other than those the user configured or the frontmost app
  the runtime must name to explain a decision;
- file paths under the user's home directory beyond the documented
  configuration location.

Event-tap hot paths do not log per event.

## Accessibility

Every interactive control exposes an accessible name. Icon-only controls set
`accessibilityLabel`, and `accessibilityHint` where the outcome is not implied
by the label. Meaning is never carried by colour alone. See
[`docs/accessibility.md`](docs/accessibility.md) for the verified keyboard
paths and the known limitations.

## Documentation boundaries

Each fact has one home.

| Fact | Home |
|---|---|
| Build, test, validation, and release commands | This file |
| High-risk operations, machine-owned paths, constraints | This file |
| Architecture and logging policy | This file |
| Product description, install, configuration, support, privacy | `README.md` |
| Accessibility behaviour and limitations | `docs/accessibility.md` |
| Standard conformance results | `.github/conformance.yml` and `docs/self-assessment.md` |
| User-visible change history | `CHANGELOG.md` |

Do not restate a fact in a second location. Link to its home instead.

## Related repositories

- [`trsdn/.github`](https://github.com/trsdn/.github) — Repository Quality
  Standard and shared community health files.
- [`trsdn/design-system`](https://github.com/trsdn/design-system) — Instrument
  Workshop, the design language vendored into `docs/assets/`.
