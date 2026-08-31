# Accessibility

How Ptions+ behaves with assistive technology, what has been verified, and what
does not work yet. Last reviewed 2026-08-31 against version 1.2.0.

Ptions+ is a menu bar utility with no Dock icon. Its interface is the menu bar
dropdown, the Settings window, and the About window.

## Keyboard operation

Verified manually on macOS with Full Keyboard Access enabled
(System Settings → Keyboard → Keyboard navigation).

| Surface | Path |
|---|---|
| Menu bar dropdown | Focus the menu bar with `Ctrl+F8`, arrow to the Ptions+ item, `Return` to open. Arrow keys move through Enabled, Settings, About, and Quit. |
| Quit | `Cmd+Q` while the dropdown is open. |
| Settings window | `Tab` and `Shift+Tab` move through the tab bar, the profile sidebar, and every control in the profile editor. `Space` activates a button, `Return` opens a menu. |
| Profile sidebar | Arrow keys move the selection. The add-profile toolbar button is in the tab order. |
| Assign a shortcut | Tab to the Assign menu, `Return` to open, arrow keys to a system action or preset, `Return` to apply. |
| App picker | The search field takes focus on open. `Tab` to the list, arrow keys to move, `Return` to select, `Esc` to dismiss. |

Focus indicators are the system ones; Ptions+ does not draw its own and does not
suppress them.

## Assistive technology

Every interactive control exposes an accessible name. Icon-only controls carry
an explicit label:

| Control | Accessible name |
|---|---|
| Menu bar icon | "Ptions+, enabled" or "Ptions+, disabled" |
| Add profile (`+` toolbar button) | "Add app profile" |
| Assign / Change menu | "Assign mapping for Back", and so on per button |
| Clear mapping (`✕`) | "Clear mapping for Back", and so on per button |
| App picker row | The app name, with "Already configured" as its value where it applies |
| Shortcut recorder | "Shortcut recorder", with help text describing what to press |

Purely decorative images — the permission-guide icon, app icons in the picker,
and the About window icon — are hidden from assistive technology so they are not
announced as unlabelled graphics.

## Colour and contrast

No state is signalled by colour alone. The event-tap status row, the
configuration warning, and the permission warning each pair their colour with a
text label and an SF Symbol. Ptions+ uses system colours and system text styles
throughout, so it follows the system appearance, the accent colour, Increase
Contrast, and Reduce Transparency without special handling.

Text uses the standard SwiftUI text styles rather than fixed point sizes, so it
tracks the system text size.

## Known limitations

These are real and are stated rather than left to be discovered.

1. **Recording a custom shortcut requires a physical key press.** The recorder
   captures raw key events in order to store a physical key code, so a shortcut
   cannot be recorded through VoiceOver's keyboard commander or through a
   switch-control scanning interface. The system actions and the 16 presets are
   fully reachable from the Assign menu without recording anything, and cover
   the common cases.

2. **Accessibility permission is mandatory and is granted outside the app.**
   Ptions+ cannot intercept mouse buttons or post keyboard events without it.
   Granting it happens in System Settings, which Ptions+ can only open for you.

3. **The mapped buttons themselves are a pointing device.** Ptions+ makes extra
   mouse buttons useful; it does not provide a keyboard-only route to the
   actions those buttons trigger. Every action it can send — Mission Control,
   Spotlight, and the rest — already has a system keyboard shortcut.

4. **The Debug monitor is a live event log.** It updates as you move the mouse,
   which makes it noisy under a screen reader. It is a troubleshooting tool and
   nothing in normal configuration requires it.

5. **VoiceOver has not been tested against every third-party screen reader.**
   Verification has been done with VoiceOver on macOS only.

## Reporting a problem

Accessibility defects are ordinary bugs. Open one on the
[issue tracker](https://github.com/trsdn/PtionsPlus/issues) and say which
assistive technology and which macOS version you were using.
