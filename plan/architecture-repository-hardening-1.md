---
goal: Dependency-ordered implementation of PtionsPlus repository findings
version: 1.0
date_created: 2026-07-24
last_updated: 2026-07-26
owner: trsdn/PtionsPlus maintainers
status: 'Completed'
tags: [architecture, reliability, security, testing, release, documentation]
---

# Introduction

![Status: Completed](https://img.shields.io/badge/status-Completed-brightgreen)

This plan implements GitHub issues [#1 through #24](https://github.com/trsdn/PtionsPlus/issues) against audited commit `2f9a147c695be94e79d7c54e45164b20bf8fd3f3`. It establishes CI and persistence safety before runtime refactoring, creates one reusable event-state test seam for the related event issues, preserves existing user configuration, and ends with signed artifact verification and synchronized documentation.

## 1. Requirements & Constraints

- **REQ-001**: Implement all acceptance criteria from issues #1 through #24 or record an explicit superseding issue before closing any finding.
- **REQ-002**: Establish CI for the exact commit under test before merging runtime, persistence, or release behavior changes.
- **REQ-003**: Issue #20 owns the reusable event-state harness used by issues #2, #3, #4, and #10.
- **REQ-004**: Implement issues #6 and #7 through one configuration validation, persistence, and recovery policy.
- **REQ-005**: Implement issues #15, #18, and #19 through one release-artifact pipeline change set.
- **REQ-006**: Implement issues #16 and #17 together so release signing is gated by tests and separated from release publication permissions.
- **REQ-007**: Continue decoding existing unversioned JSON configurations and preserve every valid profile, mapping, shortcut, global override, enabled state, and mouse model.
- **REQ-008**: Preserve recorded `KeyboardShortcut` values as physical key recordings; layout-aware translation applies only to semantic preset shortcuts.
- **REQ-009**: Preserve mappings hidden by a mouse-model change as dormant data and never delete them automatically.
- **REQ-010**: Make `SMAppService.mainApp.status` authoritative after issue #8; legacy `launchAtLogin` JSON values must not change system registration.
- **SEC-001**: Never silently overwrite an unreadable, unsupported, or semantically invalid configuration.
- **SEC-002**: Remove strong executable linkage to the private `CoreDockSendNotification` symbol.
- **SEC-003**: Keep Apple signing/notarization credentials out of the write-enabled GitHub release publication job.
- **CON-001**: Retain macOS 13 as the deployment target.
- **CON-002**: Add no third-party runtime dependencies.
- **CON-003**: Retain manual mouse-model selection and remove the unused `MouseDetector` implementation for issue #24.
- **CON-004**: Use the selected `MouseModel` to gate runtime mappings; unavailable buttons must pass through.
- **CON-005**: Remove the missing `AccentColor` build setting rather than introduce an unrequested visual change.
- **CON-006**: Remove references to the nonexistent deploy script rather than add a new installation script.
- **GUD-001**: Keep every change set independently reviewable and green before merging dependent work.
- **GUD-002**: Use explicit errors and user-visible recovery states instead of broad catches or silent defaults.
- **GUD-003**: Do not parse undocumented `com.apple.symbolichotkeys` preference formats; document settings-dependent presets and retain custom recording as the fallback.
- **GUD-004**: Run no keyboard-layout lookup, symbol resolution, formatting, logging, or application discovery synchronously inside the event-tap callback.
- **GUD-005**: Use a bounded Debug history capacity of exactly 500 events.
- **GUD-006**: Final ZIP and DMG artifacts must contain the same stapled application bytes.
- **PAT-001**: Introduce protocols and injected fakes around event-tap management, keyboard posting, Accessibility trust, ServiceManagement, app discovery, configuration I/O, and dynamic symbol resolution.

### Dependency-ordered change sets

| Order | Issues | Dependencies | Parallel execution |
|---|---:|---|---|
| 1 | #16, #17 | None | First |
| 2 | #6, #7 | Order 1 | Parallel with orders 3, 4, and 5 |
| 3 | #15, #18, #19 | Order 1 | Parallel with orders 2, 4, and 5 |
| 4 | #21 | Order 1 | Parallel |
| 5 | #22 | Order 1 | Parallel; resolve README conflicts after order 3 |
| 6 | #20 | Order 2 | Sequential foundation |
| 7 | #2, #3 | Order 6 | Sequential |
| 8 | #1, #4, #5 | Order 7 | Sequential |
| 9 | #8, #11 | Orders 2 and 8 | Parallel with each other |
| 10 | #9, #14 | Order 8 | Sequential |
| 11 | #10, #24 | Orders 6, 9, and 10 | Sequential integration |
| 12 | #13 | Orders 6 and 10 | Sequential |
| 13 | #12 | Order 12 | Sequential |
| 14 | #23 | All preceding orders | Final documentation and release gate |

### Per-issue implementation map

| Issue | Files, types, and functions | Measurable completion |
|---|---|---|
| #1 | `PtionsPlus/PtionsApp.swift`; `AppDelegate.applicationDidFinishLaunching`; new `RuntimeServiceCoordinator.reconcile()`; `MenuBarView` enabled binding | Trusted/untrusted and enabled/disabled startup matrix passes; delayed permission grant cannot start a disabled service |
| #2 | New `EventStateMachine`, `KeyboardStateCoordinator`; `EventTapService.stop()`; `AppDelegate.applicationWillTerminate` | Stop and termination emit all required key-up events; overlapping shortcuts retain shared modifiers until final release |
| #3 | `EventStateMachine.handleButton`; new `ButtonPressState` | Every up event uses its down event's suppression decision despite app or configuration changes |
| #4 | `EventTapService.handleEvent`; new `EventTapBackend` and `EventTapStatus` | Both disabled event types recover or fail visibly; reported state matches backend state |
| #5 | `AccessibilityChecker.startMonitoring`; `RuntimeServiceCoordinator`; menu and General status UI | Revocation stops interception; restoration starts only when enabled; failures are visible |
| #6 | `MappingStore.addProfile`; new `ConfigurationValidator`; `ProfileListView`; `AppPickerView` | Duplicate adds are rejected and loaded duplicates enter explicit repair |
| #7 | `AppConfiguration`; new `ConfigurationRepository`; `MappingStore.commit`; new configuration recovery UI | Corrupt, future, invalid, and unwritable fixtures pass; unreadable originals remain unchanged until explicit recovery |
| #8 | New `LaunchAtLoginService` and `LaunchAtLoginViewModel`; `SettingsView.GeneralTab`; `AppConfiguration` migration | Every `SMAppService.Status` and operation failure is represented and tested |
| #9 | `DebugMonitorView`; new `DebugMonitorModel`; diagnostics subscription API | Subscription detaches on disappearance; history never exceeds 500; formatter is shared |
| #10 | `MappingStore.mapping`; new `modelChangeImpact` and `setMouseModel`; `SettingsView.GeneralTab` | Unavailable buttons pass through; model changes warn before hiding active mappings; stored data remains intact |
| #11 | New `ApplicationDiscoveryService`; `AppPickerView`; `ProfileListView` | User, system, nested, and external apps deduplicate by bundle ID; failures and manual selection are supported |
| #12 | New `KeyboardLayoutResolver` and `PresetActionExecutor`; `KeySimulator`; `ProfileEditorView` | US, German QWERTZ, and French AZERTY logical shortcut tests pass; recorded shortcut JSON is unchanged |
| #13 | New `CoreDockClient`; `PresetActionExecutor`; preset availability UI | Symbol-present and symbol-missing tests pass; executable has no undefined `_CoreDockSendNotification` symbol |
| #14 | `EventTapService`; `KeySimulator`; `PtionsApp.swift` logging | No successful per-event bundle, profile, action, or shortcut log remains |
| #15 | `scripts/sign-release.sh`; `scripts/notarize.sh`; new `scripts/verify-release-artifacts.sh` | Extracted ZIP app and mounted DMG app both pass codesign, stapler, and Gatekeeper checks |
| #16 | `.github/workflows/release.yml`; new `.github/dependabot.yml` | Every action uses a full SHA; signing has read-only contents permission and no persisted token |
| #17 | New `.github/workflows/ci.yml`; `.github/workflows/release.yml` | Pull requests and pushes run build/tests; signing depends on tests for the exact tag commit |
| #18 | New `scripts/verify-version.sh`; release workflow and scripts | Invalid or mismatched tags fail before signing; archive plist version/build matches project settings |
| #19 | `scripts/notarize.sh`; artifact verifier; `README.md` | Checksum contains only `Ptions+.dmg`; clean-directory verification succeeds |
| #20 | New `EventStateMachine`, `EventTapBackend`, and injected `EventActionExecuting`; new tests | Required event cases run without posting real system input |
| #21 | `PtionsPlus.xcodeproj/project.pbxproj` | Debug, Release, unit-test, UI-test, and analyze output contains no missing `AccentColor` warning |
| #22 | `README.md`; `CLAUDE.md`; `.gitignore`; new `scripts/check-documentation.sh` | No deploy-script reference remains and every documented repository script exists |
| #23 | `README.md`; `CLAUDE.md`; `docs/index.html`; `CHANGELOG.md`; consistency checks | Documentation matches final architecture, workflows, version, models, and release artifacts |
| #24 | Delete `PtionsPlus/Services/MouseDetector.swift`; update project and documentation references | Build contains no `MouseDetector` or `ConnectedMouse`; manual selection is explicit |

## 2. Implementation Steps

### Implementation Phase 1 - CI and workflow security foundation

- **GOAL-001**: Establish mandatory tests and secure workflow boundaries before changing runtime or persistence behavior.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Add `.github/workflows/ci.yml` with `pull_request`, `push` to `main`, and `workflow_call`; run Debug unit tests, Release build, analyze, and a separate UI-smoke job using `-only-testing`. | Yes | 2026-07-26 |
| TASK-002 | Upload failed `.xcresult` bundles with the reviewed full SHA for `actions/upload-artifact@v5`; do not cache DerivedData. | Yes | 2026-07-26 |
| TASK-003 | Refactor `.github/workflows/release.yml` so tests use the resolved tag ref and signing has `needs: tests`; move GitHub Release creation/upload into a separate publication job with `contents: write`. | Yes | 2026-07-26 |
| TASK-004 | Pin checkout, upload-artifact, and download-artifact to reviewed full SHAs for their current Node 24 releases; set `persist-credentials: false`. | Yes | 2026-07-26 |
| TASK-005 | Add `.github/dependabot.yml` for weekly `github-actions` updates and document review of each upstream tag-to-SHA association. | Yes | 2026-07-26 |

Completion criteria:

- A pull request executes unit, build, analyze, and UI jobs.
- A release dry run cannot enter signing when any required test job fails.
- Only the publication job has `contents: write`; it receives no Apple credentials or imported keychain.

### Implementation Phase 2 - Parallel configuration, release, and hygiene work

- **GOAL-002**: Land configuration integrity, release correctness, and low-risk repository hygiene. The configuration, release, AccentColor, and deploy-documentation task groups may execute in parallel.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Add an `AppConfiguration.schemaVersion`; treat unversioned files as schema 1 and define schema 2 as the validated persistence format. Parse the schema before decoding version-sensitive enum fields and reject versions greater than the supported version. | Yes | 2026-07-26 |
| TASK-007 | Add `ConfigurationRepository.load/save/backup` and `ConfigurationValidator.validate`; require exactly one Default profile, unique non-nil bundle identifiers, one mapping per button per profile, and deduplicated global buttons. | Yes | 2026-07-26 |
| TASK-008 | Refactor `MappingStore` mutations through transactional `commit`: validate and atomically write a candidate before publishing it. Retain the previous published configuration and expose `ConfigurationPersistenceState` when a write fails. | Yes | 2026-07-26 |
| TASK-009 | Add recovery UI for corrupt, unsupported, or invalid data. Block runtime activation and mutation until `Retry`, `Apply Repair`, or `Reset` succeeds; `Apply Repair` and `Reset` must first create `config.json.backup-<UTC timestamp>-<UUID>.json`. | Yes | 2026-07-26 |
| TASK-010 | Reject duplicate profiles in `MappingStore.addProfile`; route loaded duplicates through the same validator and repair report; disable or label configured apps in `AppPickerView`. | Yes | 2026-07-26 |
| TASK-011 | Refactor `scripts/sign-release.sh` to produce only the signed archive and `build/notarization/Ptions+-submission.zip`. | Yes | 2026-07-26 |
| TASK-012 | Refactor `scripts/notarize.sh` to submit the temporary ZIP, staple and validate the archive app, recreate the final ZIP and DMG from that app, notarize and staple the DMG, then invoke `scripts/verify-release-artifacts.sh`. | Yes | 2026-07-26 |
| TASK-013 | Add tag regex `^v[0-9]+\.[0-9]+\.[0-9]+$`, compare the tag with `MARKETING_VERSION` before build, and validate `CFBundleShortVersionString` and `CFBundleVersion` after archive. | Yes | 2026-07-26 |
| TASK-014 | Generate `dist/Ptions+.dmg.sha256` from inside `dist/`; verify it after copying the DMG and checksum into a clean temporary directory. | Yes | 2026-07-26 |
| TASK-015 | Remove both app-target `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` assignments from `PtionsPlus.xcodeproj/project.pbxproj`. | Yes | 2026-07-26 |
| TASK-016 | Remove `scripts/deploy.sh` references from `README.md` and `CLAUDE.md`, remove the obsolete `.gitignore` rule, and add `scripts/check-documentation.sh` to verify documented repository scripts. | Yes | 2026-07-26 |

Completion criteria:

- Corrupt JSON, unknown enum, future schema, missing Default profile, duplicate IDs, duplicate mappings, and failed writes have deterministic tests.
- No invalid configuration is overwritten without explicit recovery and backup.
- Final ZIP and DMG contain the same stapled application bytes.
- Checksum verification succeeds using only downloaded artifact basenames.
- All build variants are free of the AccentColor warning and documentation-script references validate.

### Implementation Phase 3 - Event-state architecture owned by issue #20

- **GOAL-003**: Extract deterministic event decisions and test doubles before changing event behavior.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-017 | Add `PtionsPlus/Services/EventStateMachine.swift` containing `RuntimeMouseEvent`, `EventDisposition`, `ButtonPressState`, `MappingResolving`, and `EventActionExecuting`. | Yes | 2026-07-26 |
| TASK-018 | Move mapping resolution and pass/suppress decisions from `EventTapService.handleEvent` into `EventStateMachine.handleButton(number:isDown:bundleIdentifier:)`. | Yes | 2026-07-26 |
| TASK-019 | Convert `KeySimulator` from static-only calls to an injected executor and add a `KeyboardEventPosting` seam so tests record commands without posting `CGEvent` input. | Yes | 2026-07-26 |
| TASK-020 | Add `EventTapBackend` around tap creation, enablement, state checks, run-loop source management, and teardown. | Yes | 2026-07-26 |
| TASK-021 | Add `EventStateMachineTests.swift` for mapped and unmapped pairs, global overrides, unknown buttons, ordinary shortcuts, held shortcuts, and profile lookup; add CGEvent translation coverage using fabricated events only. | Yes | 2026-07-26 |

Completion criteria:

- Event-state tests post zero real keyboard or mouse events.
- `EventTapService` contains only CGEvent translation, diagnostics forwarding, backend lifecycle, and state-machine delegation.
- Existing mapping behavior remains unchanged before the dependent bug fixes land.

### Implementation Phase 4 - Paired mouse state and held-key correctness

- **GOAL-004**: Implement issues #2 and #3 together because both require durable per-press state and balanced release semantics.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-022 | Store the first down event's `EventDisposition` in `ButtonPressState`; every matching up uses that stored result without resolving the active app or configuration again. | Yes | 2026-07-26 |
| TASK-023 | Assign each first down a press identifier; repeated downs for the same button increment a depth counter without replacing or retriggering the original press; releases decrement depth and finalize at zero. | Yes | 2026-07-26 |
| TASK-024 | Add `KeyboardStateCoordinator` reference counts for every modifier and non-modifier key; emit physical down only at count zero-to-one and up only at one-to-zero, including standalone modifiers. | Yes | 2026-07-26 |
| TASK-025 | Make `EventStateMachine.stop()` drain every active press and release all held input before `EventTapService` disables or removes the tap; invoke the same cleanup from `AppDelegate.applicationWillTerminate`. | Yes | 2026-07-26 |
| TASK-026 | Add tests for app/configuration changes between down and up, overlapping presses, duplicate downs, unmatched ups, shared modifiers, shared keys, service stop, and termination. | Yes | 2026-07-26 |

Completion criteria:

- No test sequence leaves a positive key or modifier reference count after final release or stop.
- Every suppressed down has a suppressed matching up after active-profile changes.
- Overlapping input cannot overwrite an existing held shortcut and releases only after the final matching up.

### Implementation Phase 5 - Enabled, Accessibility, and event-tap lifecycle

- **GOAL-005**: Implement issues #1, #4, and #5 through one runtime reconciliation model.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-027 | Add `RuntimeServiceCoordinator.start/stop/reconcile`; its invariant is to run the event tap only when configuration is usable, `isEnabled` is true, and Accessibility is trusted. | Yes | 2026-07-26 |
| TASK-028 | Replace direct enabled-state mutation in `MenuBarView` with transactional `MappingStore.setEnabled`; remove direct `EventTapService.start/stop` calls from the view. | Yes | 2026-07-26 |
| TASK-029 | Rename Accessibility polling to idempotent `startMonitoring/stopMonitoring`, run it for the application lifetime, and remove `PermissionGuideView.onDisappear` monitoring shutdown. | Yes | 2026-07-26 |
| TASK-030 | Add `EventTapStatus` cases for stopped, running, permission denied, recovering, and failed; handle both disabled event types, verify backend enablement, and recreate once if verification fails. | Yes | 2026-07-26 |
| TASK-031 | Surface runtime failures in the menu and General settings with Retry and Open Accessibility Settings actions. | Yes | 2026-07-26 |
| TASK-032 | Add coordinator/backend tests for every startup combination, permission grant after disable, revoke/restore, enable while untrusted, both disabled events, recreation success, and recreation failure. | Yes | 2026-07-26 |

Completion criteria:

- Disabled startup never prompts for Accessibility and never starts interception.
- Permission revocation stops the service and releases held inputs.
- Permission restoration starts only when enabled; failed recovery is visible and reported as not running.

### Implementation Phase 6 - Parallel launch-at-login and app discovery improvements

- **GOAL-006**: Implement issues #8 and #11 in parallel after configuration APIs stabilize.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-033 | Add `LaunchAtLoginManaging` and `LaunchAtLoginService` wrappers around `SMAppService.mainApp.status`, `register`, `unregister`, and the login-items System Settings action. | Yes | 2026-07-26 |
| TASK-034 | Add `LaunchAtLoginViewModel`; refresh on view appearance and `NSApplication.didBecomeActiveNotification`; represent enabled, disabled, requires approval, not found, and operation failure states. | Yes | 2026-07-26 |
| TASK-035 | Remove `launchAtLogin` from `AppConfiguration`, advance the persistence schema to 3, and accept schema 1 and 2 data while ignoring the legacy value. | Yes | 2026-07-26 |
| TASK-036 | Add `ApplicationDiscoveryService` that recursively scans standard local, user, system, and mounted-volume roots off the main thread, supports cancellation, and publishes deduplicated results on the main queue. | Yes | 2026-07-26 |
| TASK-037 | Refactor `AppPickerView` around an injected view model with loading, partial results, failure, cancellation, configured-app badges, and an `NSOpenPanel` manual `.app` fallback. | Yes | 2026-07-26 |
| TASK-038 | Add fake-backed tests for every ServiceManagement status/failure and for discovery deduplication, cancellation, external apps, missing bundle identifiers, and discovery errors. | Yes | 2026-07-26 |

Completion criteria:

- Launch-at-login UI equals the service state after every operation and app reactivation.
- Legacy JSON cannot register or unregister the login item.
- Application discovery performs no traversal or icon resolution on the main thread and cannot add duplicate profiles.

### Implementation Phase 7 - Diagnostics and manual mouse-model behavior

- **GOAL-007**: Bound diagnostics, remove sensitive callback logging, enforce model gating, and remove unused HID detection code.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-039 | Replace `EventTapService.onEvent` and unused `lastEvent` publication with a cancellable diagnostics subscription token; avoid main-queue dispatch when no subscriber exists. | Yes | 2026-07-26 |
| TASK-040 | Add `DebugMonitorModel.start/stop`; maintain a FIFO capacity of exactly 500 events and use one static formatter or `Date.FormatStyle`. | Yes | 2026-07-26 |
| TASK-041 | Remove successful per-event `NSLog` calls from `EventTapService` and `KeySimulator`; retain only `Logger` lifecycle/error messages with explicit privacy annotations. | Yes | 2026-07-26 |
| TASK-042 | Add tests proving diagnostics stop after unsubscribe, truncate at 500, and remain independent of production logging. | Yes | 2026-07-26 |
| TASK-043 | Guard runtime resolution with `configuration.mouseModel.availableButtons.contains(button)`; unavailable buttons create a pass-through press state and execute no action. | Yes | 2026-07-26 |
| TASK-044 | Add `MappingStore.modelChangeImpact(to:)` and transactional `setMouseModel`; `GeneralTab` must confirm before hiding any active mapping or global override and cancellation must retain the old model. | Yes | 2026-07-26 |
| TASK-045 | Delete `PtionsPlus/Services/MouseDetector.swift`, its project build/file/group references, and documentation references; document one manually selected model. | Yes | 2026-07-26 |
| TASK-046 | Add event-state, store, and UI tests proving unavailable mappings are dormant, warnings enumerate affected buttons, and switching back restores unchanged mappings. | Yes | 2026-07-26 |

Completion criteria:

- Leaving Debug produces no later history changes and history remains at or below 500 entries.
- Unified logging contains no per-event frontmost bundle identifier, profile name, action, or shortcut.
- Hidden mappings never execute and are never deleted.
- Source and built products contain no `MouseDetector` or `ConnectedMouse`.

### Implementation Phase 8 - Preset-action hardening

- **GOAL-008**: Remove eager private linkage before making logical presets keyboard-layout aware.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-047 | Add `CoreDockClient` with injected `SymbolResolving`; resolve `CoreDockSendNotification` once with `dlopen` and `dlsym`, then cache a typed `@convention(c)` function only when present. | Yes | 2026-07-26 |
| TASK-048 | Add `PresetActionExecutor.availability(for:)`; if CoreDock is unavailable, saved Dock actions become visibly unavailable and their mouse events pass through rather than being swallowed. | Yes | 2026-07-26 |
| TASK-049 | Add symbol-present and symbol-missing tests plus a build check that `nm -u` does not list `_CoreDockSendNotification`. | Yes | 2026-07-26 |
| TASK-050 | Add `KeyboardLayoutResolver` using TIS input-source data and `UCKeyTranslate`; build an immutable character-to-key-code/modifier map outside the callback and invalidate it on keyboard-input-source changes. | Yes | 2026-07-26 |
| TASK-051 | Replace ANSI constants for logical preset characters with `LogicalShortcut` descriptors; keep layout-independent Tab, Space, arrow, function, and numeric keys physical and leave recorded shortcut decoding unchanged. | Yes | 2026-07-26 |
| TASK-052 | Use a supported semantic action for Screenshot when available, with layout-correct Command-Shift-5 as fallback; mark Spotlight and Notification Center as settings-dependent rather than parsing undocumented preferences. | Yes | 2026-07-26 |
| TASK-053 | Update preset UI help so settings-dependent presets describe their default macOS shortcut and direct reassigned users to custom recording; resolver failure marks a preset unavailable and passes the event through. | Yes | 2026-07-26 |
| TASK-054 | Add deterministic US, German QWERTZ, and French AZERTY fixtures covering every logical preset character plus byte-equivalent round-trip tests for existing custom shortcuts. | Yes | 2026-07-26 |

Completion criteria:

- Application launch succeeds when the CoreDock symbol is absent.
- Undo resolves to logical `Z` for US, German, and French fixture layouts.
- No layout lookup, formatting, or symbol resolution executes for each mouse event.
- Existing recorded shortcuts retain their physical key codes and modifiers.

### Implementation Phase 9 - Documentation synchronization and final release gate

- **GOAL-009**: Complete issue #23 only after final architecture, models, workflows, and release behavior are stable.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-055 | Update `CLAUDE.md` with current tests and CI commands, `PresetAction`, lifetime Accessibility monitoring, event-state architecture, dynamic CoreDock fallback, manual model selection, and no deploy command. | Yes | 2026-07-26 |
| TASK-056 | Update `README.md` with manual model selection, four release outputs, final notarization order, portable checksum verification, test commands, and the final source tree. | Yes | 2026-07-26 |
| TASK-057 | Update `docs/index.html` `softwareVersion` to the Xcode `MARKETING_VERSION`, add MX Master 4 compatibility content, and extend `bump-version.sh` plus documentation checks to update or verify website metadata. | Yes | 2026-07-26 |
| TASK-058 | Resolve the MX Master 3 documentation mismatch by aligning the supported model table to buttons 2 through 5; retain physical-device revalidation as a release prerequisite when compatible hardware is connected. | Yes | 2026-07-28 |
| TASK-059 | Run all validation gates and wire protected release checks. Unit and UI suites, Release build, analysis, repository checks, binary checks, Developer ID signing, app/DMG notarization, stapling, Gatekeeper assessment, packaged-app comparison, and checksum verification pass. | Yes | 2026-07-28 |

Completion criteria:

- Documentation checks find no obsolete type, script, version, model, architecture, or artifact-count reference.
- The committed MX Master 3 model table is internally consistent; physical revalidation is recorded as a release prerequisite when hardware is available.
- Every issue-specific completion condition is satisfied.
- A release from the final commit passes exact-commit tests, version validation, signing, notarization, stapling, artifact extraction/mount validation, and checksum verification.

## 3. Alternatives

- **ALT-001**: Wire up `MouseDetector`; rejected because it introduces new asynchronous IOKit behavior, hardware mapping maintenance, and UI scope while current behavior is manual.
- **ALT-002**: Keep hidden mappings active after model changes; rejected because active behavior would remain uninspectable.
- **ALT-003**: Add an `AccentColor` asset; rejected to avoid an unrequested visual behavior change.
- **ALT-004**: Add `scripts/deploy.sh`; rejected because existing build/copy commands are sufficient and avoid adding installation/process-management behavior.
- **ALT-005**: Silently auto-repair invalid configuration; rejected because conflict resolution could discard user mappings without informed recovery.
- **ALT-006**: Parse undocumented macOS system-shortcut preferences; rejected because their schema and compatibility are unsupported.
- **ALT-007**: Implement all event issues in one pull request; rejected because separating the test seam, press state, lifecycle, diagnostics, and model gating produces safer reviews.

## 4. Dependencies

- **DEP-001**: Xcode 15 or later with a macOS 13-compatible SDK.
- **DEP-002**: GitHub-hosted macOS runners for unit and UI jobs.
- **DEP-003**: Existing Developer ID and Apple notarization credentials for protected artifact validation.
- **DEP-004**: Physical MX Master 3 hardware with Bluetooth and receiver access for final button-number verification.
- **DEP-005**: Built-in macOS TIS, Carbon, CoreGraphics, ServiceManagement, and Metadata APIs.
- **DEP-006**: Repository settings must expose the new CI jobs as required checks if branch protection or rulesets are enabled.

## 5. Files

- **FILE-001**: Modify `PtionsPlus/Model/ButtonMapping.swift` and `PtionsPlus/Model/MappingStore.swift`.
- **FILE-002**: Add `PtionsPlus/Model/ConfigurationRepository.swift` and `PtionsPlus/Model/ConfigurationValidation.swift`.
- **FILE-003**: Modify `PtionsPlus/PtionsApp.swift`, `AccessibilityChecker.swift`, `EventTapService.swift`, and `KeySimulator.swift`.
- **FILE-004**: Add `EventStateMachine.swift`, `EventTapBackend.swift`, `RuntimeServiceCoordinator.swift`, `LaunchAtLoginService.swift`, `ApplicationDiscoveryService.swift`, `CoreDockClient.swift`, `KeyboardLayoutResolver.swift`, and `PresetActionExecutor.swift`.
- **FILE-005**: Modify affected SwiftUI views and add `ConfigurationStatusView.swift` plus `DebugMonitorModel.swift`.
- **FILE-006**: Delete `PtionsPlus/Services/MouseDetector.swift`.
- **FILE-007**: Modify `PtionsPlus.xcodeproj/project.pbxproj` and the shared scheme only where source membership or CI behavior requires it.
- **FILE-008**: Expand `PtionsPlusTests/` with configuration, event-state, lifecycle, ServiceManagement, discovery, CoreDock, and keyboard-layout tests.
- **FILE-009**: Extend `PtionsPlusUITests/PtionsPlusUITests.swift` with recovery, model-warning, configured-app, and status smoke coverage.
- **FILE-010**: Add `.github/workflows/ci.yml` and `.github/dependabot.yml`; modify `.github/workflows/release.yml`.
- **FILE-011**: Modify all existing release scripts and add `verify-version.sh`, `verify-release-artifacts.sh`, and `check-documentation.sh`.
- **FILE-012**: Modify `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/index.html`, and `.gitignore`.

## 6. Testing

- **TEST-001**: Run unit tests with `xcodebuild -project PtionsPlus.xcodeproj -scheme "Ptions+" -configuration Debug test -only-testing:PtionsPlusTests -destination 'platform=macOS'`.
- **TEST-002**: Run UI smoke tests separately with `-only-testing:PtionsPlusUITests`.
- **TEST-003**: Test configuration files from schemas 1, 2, and 3 plus corrupt, future, duplicate, missing-default, and unwritable cases.
- **TEST-004**: Test event-state sequences without posting real system input.
- **TEST-005**: Test trusted/untrusted and enabled/disabled lifecycle matrices with fakes.
- **TEST-006**: Test Debug subscription detachment and 500-event truncation.
- **TEST-007**: Test US, German QWERTZ, and French AZERTY logical shortcut fixtures.
- **TEST-008**: Test CoreDock lookup with symbol-present and symbol-missing resolvers.
- **TEST-009**: Run Debug and Release builds plus analyze; reject new warnings.
- **TEST-010**: Run `bash -n scripts/*.sh` and `scripts/check-documentation.sh`.
- **TEST-011**: Extract the final ZIP and mount the final DMG; validate contained apps with `codesign`, `xcrun stapler validate`, and `spctl`.
- **TEST-012**: Verify the checksum from a clean directory with `shasum -a 256 -c Ptions+.dmg.sha256`.

## 7. Risks & Assumptions

- **RISK-001**: Configuration repair can resolve conflicting mappings only by selecting a canonical value; mitigate with explicit reports and byte-preserving backups.
- **RISK-002**: CoreDock remains a private API after dynamic lookup; mitigate by making it optional and passing events through when unavailable.
- **RISK-003**: Quartz does not reliably expose physical mouse identity; use balanced per-button overlap depth and guaranteed stop cleanup instead of claiming device identity.
- **RISK-004**: Spotlight and Notification Center shortcut assignments have no supported preference API; surface this limitation and retain custom recording.
- **RISK-005**: Metadata indexing can omit unindexed external apps; always expose manual `.app` selection.
- **RISK-006**: Notarization validation consumes time and credentials; execute full artifact checks only in the protected release workflow.
- **ASSUMPTION-001**: Manual mouse-model selection is the intended product behavior.
- **ASSUMPTION-002**: Existing unversioned configurations represent schema 1.
- **ASSUMPTION-003**: MX Master 3 family behavior remains buttons 2 through 5 unless hardware evidence disproves it.

## 8. Related Specifications / Further Reading

- [PtionsPlus issues #1 through #24](https://github.com/trsdn/PtionsPlus/issues)
- [CGEvent tap enablement](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap:enable:))
- [ServiceManagement `SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Foundation `NSMetadataQuery`](https://developer.apple.com/documentation/foundation/nsmetadataquery)
- [GitHub Actions security hardening](https://docs.github.com/actions/security-guides/security-hardening-for-github-actions)
- [Apple notarization workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
