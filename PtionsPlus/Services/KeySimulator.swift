import Foundation
import CoreGraphics
import AppKit
import Carbon.HIToolbox

@_silgen_name("CoreDockSendNotification")
func CoreDockSendNotification(_ notification: CFString, _ unknown: UnsafeMutableRawPointer?) -> Void

enum SystemAction: String {
    case missionControl = "com.apple.expose.awake"
    case appExpose = "com.apple.expose.front.awake"
    case showDesktop = "com.apple.showdesktop.awake"
    case launchpad = "com.apple.launchpad.toggle"
}

enum KeySimulator {
    static func simulateShortcut(_ shortcut: KeyboardShortcut) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
            NSLog("[Ptions+] Failed to create CGEvent for keyCode \(shortcut.keyCode)")
            return
        }

        let flags = shortcut.modifiers.cgEventFlags
        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func performSystemAction(_ action: SystemAction) {
        NSLog("[Ptions+] CoreDock action: \(action.rawValue)")
        CoreDockSendNotification(action.rawValue as CFString, nil)
    }

    static func performPresetAction(_ preset: PresetAction) {
        if preset.isDockAction {
            let action: SystemAction
            switch preset {
            case .missionControl: action = .missionControl
            case .appExpose: action = .appExpose
            case .showDesktop: action = .showDesktop
            case .launchpad: action = .launchpad
            default: return
            }
            performSystemAction(action)
        } else {
            let shortcut = shortcutForPreset(preset)
            NSLog("[Ptions+] Preset shortcut: \(preset.displayName) -> \(shortcut.displayString)")
            simulateShortcut(shortcut)
        }
    }

    private static func shortcutForPreset(_ preset: PresetAction) -> KeyboardShortcut {
        switch preset {
        case .notificationCenter:
            // Click on date in menu bar - simulate via Fn+N (macOS Ventura+) won't work reliably
            // Use the notification center toggle via script instead
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_N), modifiers: .init(command: true, shift: true))
        case .spotlight:
            return KeyboardShortcut(keyCode: UInt16(kVK_Space), modifiers: .init(command: true))
        case .screenshotTool:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_5), modifiers: .init(command: true, shift: true))
        case .fullscreenToggle:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_F), modifiers: .init(command: true, control: true))
        case .minimizeWindow:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_M), modifiers: .init(command: true))
        case .browserBack:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_LeftBracket), modifiers: .init(command: true))
        case .browserForward:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_RightBracket), modifiers: .init(command: true))
        case .copy:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: .init(command: true))
        case .paste:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_V), modifiers: .init(command: true))
        case .undo:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_Z), modifiers: .init(command: true))
        case .lockScreen:
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_Q), modifiers: .init(command: true, control: true))
        case .appSwitcher:
            return KeyboardShortcut(keyCode: UInt16(kVK_Tab), modifiers: .init(command: true))
        default:
            fatalError("Not a shortcut-based preset")
        }
    }
}
