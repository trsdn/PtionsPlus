import Foundation
import CoreGraphics

enum MouseModel: String, Codable, CaseIterable, Identifiable {
    case mxMaster3 = "mx_master_3"
    case mxMaster3s = "mx_master_3s"
    case mxMaster2s = "mx_master_2s"
    case mxAnywhere3 = "mx_anywhere_3"
    case mxErgo = "mx_ergo"
    case mxVertical = "mx_vertical"
    case g502 = "g502"
    case g604 = "g604"
    case generic5 = "generic_5"
    case generic3 = "generic_3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mxMaster3: return "MX Master 3"
        case .mxMaster3s: return "MX Master 3S"
        case .mxMaster2s: return "MX Master 2S"
        case .mxAnywhere3: return "MX Anywhere 3"
        case .mxErgo: return "MX Ergo"
        case .mxVertical: return "MX Vertical"
        case .g502: return "G502"
        case .g604: return "G604"
        case .generic5: return "Generic (5 Buttons)"
        case .generic3: return "Generic (3 Buttons)"
        }
    }

    var category: String {
        switch self {
        case .mxMaster3, .mxMaster3s, .mxMaster2s, .mxAnywhere3, .mxErgo, .mxVertical:
            return "Logitech MX"
        case .g502, .g604:
            return "Logitech G"
        case .generic5, .generic3:
            return "Generic"
        }
    }

    var availableButtons: [MouseButton] {
        switch self {
        case .mxMaster3, .mxMaster3s, .mxMaster2s:
            return [.middle, .back, .forward, .button5]
        case .mxAnywhere3:
            return [.middle, .back, .forward]
        case .mxErgo:
            return [.middle, .back, .forward]
        case .mxVertical:
            return [.middle, .back, .forward]
        case .g502:
            return [.middle, .back, .forward, .button5, .button6, .button7, .button8]
        case .g604:
            return [.middle, .back, .forward, .button5, .button6, .button7, .button8, .button9, .button10, .button11]
        case .generic5:
            return [.middle, .back, .forward, .button5, .button6]
        case .generic3:
            return [.middle, .back, .forward]
        }
    }

    var buttonNames: [MouseButton: String] {
        switch self {
        case .mxMaster3, .mxMaster3s, .mxMaster2s:
            return [.middle: "Middle Click", .back: "Back", .forward: "Forward", .button5: "Thumb Button"]
        case .g502:
            return [.middle: "Middle Click", .back: "Back", .forward: "Forward",
                    .button5: "G4", .button6: "G5", .button7: "G7", .button8: "G8"]
        case .g604:
            return [.middle: "Middle Click", .back: "Back", .forward: "Forward",
                    .button5: "G4", .button6: "G5", .button7: "G6", .button8: "G7",
                    .button9: "G8", .button10: "G9", .button11: "G10"]
        default:
            return [:]
        }
    }
}

enum MouseButton: Int, Codable, CaseIterable, Identifiable {
    case middle = 2
    case back = 3
    case forward = 4
    case button5 = 5
    case button6 = 6
    case button7 = 7
    case button8 = 8
    case button9 = 9
    case button10 = 10
    case button11 = 11

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .middle: return "Middle Click"
        case .back: return "Back"
        case .forward: return "Forward"
        case .button5: return "Button 5"
        case .button6: return "Button 6"
        case .button7: return "Button 7"
        case .button8: return "Button 8"
        case .button9: return "Button 9"
        case .button10: return "Button 10"
        case .button11: return "Button 11"
        }
    }

    func displayName(for model: MouseModel) -> String {
        model.buttonNames[self] ?? displayName
    }
}

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: ModifierFlags

    struct ModifierFlags: Codable, Equatable {
        var command: Bool = false
        var option: Bool = false
        var control: Bool = false
        var shift: Bool = false

        var cgEventFlags: CGEventFlags {
            var flags = CGEventFlags()
            if command { flags.insert(.maskCommand) }
            if option { flags.insert(.maskAlternate) }
            if control { flags.insert(.maskControl) }
            if shift { flags.insert(.maskShift) }
            return flags
        }

        var displayComponents: [String] {
            var parts: [String] = []
            if control { parts.append("\u{2303}") }
            if option { parts.append("\u{2325}") }
            if shift { parts.append("\u{21E7}") }
            if command { parts.append("\u{2318}") }
            return parts
        }

        var isEmpty: Bool {
            !command && !option && !control && !shift
        }
    }

    var displayString: String {
        let modStr = modifiers.displayComponents.joined()
        let keyName = KeyCodeMap.nameForKeyCode(keyCode)
        return modStr + keyName
    }
}

enum PresetAction: String, CaseIterable, Identifiable, Codable {
    // CoreDock system actions
    case missionControl = "mission_control"
    case appExpose = "app_expose"
    case showDesktop = "show_desktop"
    case launchpad = "launchpad"
    // Keyboard shortcut actions
    case notificationCenter = "notification_center"
    case spotlight = "spotlight"
    case screenshotTool = "screenshot_tool"
    case fullscreenToggle = "fullscreen_toggle"
    case minimizeWindow = "minimize_window"
    case browserBack = "browser_back"
    case browserForward = "browser_forward"
    case copy = "copy"
    case paste = "paste"
    case undo = "undo"
    case lockScreen = "lock_screen"
    case appSwitcher = "app_switcher"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Launchpad"
        case .notificationCenter: return "Notification Center"
        case .spotlight: return "Spotlight"
        case .screenshotTool: return "Screenshot Tool"
        case .fullscreenToggle: return "Fullscreen Toggle"
        case .minimizeWindow: return "Minimize Window"
        case .browserBack: return "Browser Back"
        case .browserForward: return "Browser Forward"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .undo: return "Undo"
        case .lockScreen: return "Lock Screen"
        case .appSwitcher: return "App Switcher"
        }
    }

    var category: String {
        switch self {
        case .missionControl, .appExpose, .showDesktop, .launchpad:
            return "System"
        case .notificationCenter, .spotlight, .screenshotTool, .lockScreen:
            return "macOS"
        case .fullscreenToggle, .minimizeWindow:
            return "Window"
        case .browserBack, .browserForward:
            return "Navigation"
        case .copy, .paste, .undo, .appSwitcher:
            return "General"
        }
    }

    /// True if handled via CoreDockSendNotification, false if via keyboard shortcut
    var isDockAction: Bool {
        switch self {
        case .missionControl, .appExpose, .showDesktop, .launchpad:
            return true
        default:
            return false
        }
    }
}

struct ButtonMapping: Codable, Identifiable {
    var id: UUID = UUID()
    var button: MouseButton
    var shortcut: KeyboardShortcut?
    var systemAction: PresetAction?

    var isActive: Bool {
        shortcut != nil || systemAction != nil
    }

    var displayString: String {
        if let action = systemAction {
            return action.displayName
        }
        if let shortcut = shortcut {
            return shortcut.displayString
        }
        return "Not assigned"
    }
}

struct AppProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var bundleIdentifier: String?
    var mappings: [ButtonMapping]

    var isDefault: Bool {
        bundleIdentifier == nil
    }

    static func makeDefault() -> AppProfile {
        AppProfile(
            name: "Default",
            bundleIdentifier: nil,
            mappings: MouseButton.allCases.map { button in
                var mapping = ButtonMapping(button: button)
                if button == .button5 {
                    mapping.systemAction = .missionControl
                }
                return mapping
            }
        )
    }
}

struct AppConfiguration: Codable {
    var profiles: [AppProfile]
    var isEnabled: Bool = true
    var launchAtLogin: Bool = false
    var mouseModel: MouseModel = .mxMaster3

    static var empty: AppConfiguration {
        AppConfiguration(profiles: [AppProfile.makeDefault()])
    }
}
