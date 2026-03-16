# Changelog

## 1.1.3 - 2026-03-16

- Added a proper XCTest target with regression coverage for config compatibility and effective mapping behavior.
- Added a macOS UI test target with stable smoke tests that launch the settings UI in an isolated test mode.
- Added test-only app startup hooks so UI automation can run without Accessibility prompts or event-tap side effects.

## 1.1.2 - 2026-03-16

- Added Fn / Globe shortcut support across recording, display, and shortcut simulation.
- Added Push-to-Talk mode for shortcut mappings so shortcuts can stay pressed while the mouse button is held.
- Fixed backward compatibility for saved configs after adding new shortcut and mapping fields.
- Refined the Profile editor layout so assigned values, actions, badges, and toggles are clearer and more consistent.

## 1.1.1 - 2026-03-16

- Moved the global override control from General settings into the Default profile, directly next to each button mapping.
- Added clearer app-specific messaging when a button is currently forced by the Default profile.

## 1.1.0 - 2026-03-16

- Added MX Master 4 support with the correct five configurable buttons, including Front Thumb and Thumb Gesture.
- Added global button mappings that can be applied across apps, with conflict confirmation in Settings and inherited-state handling in profile editing.
- Fixed the Accessibility settings action so it reliably opens the correct macOS settings flow.
- Added release automation for Developer ID signing, notarization, stapling, and local `.release.env` overrides.
