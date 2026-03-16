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
        pressShortcut(shortcut)
        releaseShortcut(shortcut)
    }

    static func pressShortcut(_ shortcut: KeyboardShortcut) {
        if postStandaloneModifierShortcut(shortcut, keyDown: true) {
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        postModifierEvents(for: shortcut.modifiers, keyDown: true, source: source)
        postKeyEvent(shortcut, keyDown: true, source: source)
    }

    static func releaseShortcut(_ shortcut: KeyboardShortcut) {
        if postStandaloneModifierShortcut(shortcut, keyDown: false) {
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        postKeyEvent(shortcut, keyDown: false, source: source)
        postModifierEvents(for: shortcut.modifiers, keyDown: false, source: source)
    }

    private static func postStandaloneModifierShortcut(_ shortcut: KeyboardShortcut, keyDown: Bool) -> Bool {
        guard shortcut.modifiers.isEmpty,
              let modifier = standaloneModifier(for: shortcut.keyCode),
              let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: modifier.keyCode, keyDown: keyDown) else {
            return false
        }

        event.flags = keyDown ? modifier.flag : []
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func standaloneModifier(for keyCode: UInt16) -> (keyCode: CGKeyCode, flag: CGEventFlags)? {
        switch keyCode {
        case UInt16(kVK_Function):
            return (CGKeyCode(kVK_Function), .maskSecondaryFn)
        case UInt16(kVK_Command):
            return (CGKeyCode(kVK_Command), .maskCommand)
        case UInt16(kVK_Option):
            return (CGKeyCode(kVK_Option), .maskAlternate)
        case UInt16(kVK_Control):
            return (CGKeyCode(kVK_Control), .maskControl)
        case UInt16(kVK_Shift):
            return (CGKeyCode(kVK_Shift), .maskShift)
        default:
            return nil
        }
    }

    private static func postKeyEvent(_ shortcut: KeyboardShortcut, keyDown: Bool, source: CGEventSource?) {
        guard let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: keyDown) else {
            NSLog("[Ptions+] Failed to create CGEvent for keyCode \(shortcut.keyCode)")
            return
        }

        keyEvent.flags = shortcut.modifiers.cgEventFlags
        keyEvent.post(tap: .cghidEventTap)
    }

    private static func postModifierEvents(for modifiers: KeyboardShortcut.ModifierFlags, keyDown: Bool, source: CGEventSource?) {
        let modifierSteps: [(enabled: Bool, keyCode: CGKeyCode, flag: CGEventFlags)] = [
            (modifiers.function, CGKeyCode(kVK_Function), .maskSecondaryFn),
            (modifiers.control, CGKeyCode(kVK_Control), .maskControl),
            (modifiers.option, CGKeyCode(kVK_Option), .maskAlternate),
            (modifiers.shift, CGKeyCode(kVK_Shift), .maskShift),
            (modifiers.command, CGKeyCode(kVK_Command), .maskCommand),
        ]

        let steps = keyDown ? modifierSteps : modifierSteps.reversed()
        var activeFlags = keyDown ? CGEventFlags() : modifiers.cgEventFlags

        for step in steps where step.enabled {
            if keyDown {
                activeFlags.insert(step.flag)
            } else {
                activeFlags.remove(step.flag)
            }

            guard let modifierEvent = CGEvent(keyboardEventSource: source, virtualKey: step.keyCode, keyDown: keyDown) else {
                NSLog("[Ptions+] Failed to create modifier CGEvent for keyCode \(step.keyCode)")
                continue
            }

            modifierEvent.flags = activeFlags
            modifierEvent.post(tap: .cghidEventTap)
        }
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
            return KeyboardShortcut(keyCode: UInt16(kVK_ANSI_N), modifiers: .init(function: true))
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
