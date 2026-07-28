import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "Input")

protocol KeyboardEventPosting {
    func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> Bool
}

struct CGKeyboardEventPoster: KeyboardEventPosting {
    private let source = CGEventSource(stateID: .hidSystemState)

    func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> Bool {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: keyDown
        ) else {
            logger.error("Failed to create keyboard event for key code \(keyCode, privacy: .public)")
            return false
        }

        event.flags = flags
        event.post(tap: .cghidEventTap)
        return true
    }
}

private enum ModifierKey: CaseIterable {
    case function
    case control
    case option
    case shift
    case command

    var keyCode: CGKeyCode {
        switch self {
        case .function: return CGKeyCode(kVK_Function)
        case .control: return CGKeyCode(kVK_Control)
        case .option: return CGKeyCode(kVK_Option)
        case .shift: return CGKeyCode(kVK_Shift)
        case .command: return CGKeyCode(kVK_Command)
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .function: return .maskSecondaryFn
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .command: return .maskCommand
        }
    }

    func isEnabled(in modifiers: KeyboardShortcut.ModifierFlags) -> Bool {
        switch self {
        case .function: return modifiers.function
        case .control: return modifiers.control
        case .option: return modifiers.option
        case .shift: return modifiers.shift
        case .command: return modifiers.command
        }
    }

    static func standalone(for keyCode: UInt16) -> ModifierKey? {
        allCases.first { $0.keyCode == keyCode }
    }
}

final class KeyboardStateCoordinator {
    private let eventPoster: KeyboardEventPosting
    private var modifierCounts: [ModifierKey: Int] = [:]
    private var keyCounts: [CGKeyCode: Int] = [:]

    init(eventPoster: KeyboardEventPosting = CGKeyboardEventPoster()) {
        self.eventPoster = eventPoster
    }

    func perform(_ shortcut: KeyboardShortcut) -> Bool {
        guard press(shortcut) else {
            return false
        }
        release(shortcut)
        return true
    }

    func press(_ shortcut: KeyboardShortcut) -> Bool {
        if shortcut.modifiers.isEmpty,
           let standaloneModifier = ModifierKey.standalone(for: shortcut.keyCode) {
            return retainModifier(standaloneModifier)
        }

        var retainedModifiers: [ModifierKey] = []
        for modifier in ModifierKey.allCases where modifier.isEnabled(in: shortcut.modifiers) {
            guard retainModifier(modifier) else {
                for retainedModifier in retainedModifiers.reversed() {
                    releaseModifier(retainedModifier)
                }
                return false
            }
            retainedModifiers.append(modifier)
        }

        let keyCode = CGKeyCode(shortcut.keyCode)
        let existingCount = keyCounts[keyCode, default: 0]
        keyCounts[keyCode] = existingCount + 1
        if existingCount == 0,
           !eventPoster.postKeyEvent(keyCode: keyCode, keyDown: true, flags: currentFlags) {
            keyCounts.removeValue(forKey: keyCode)
            for retainedModifier in retainedModifiers.reversed() {
                releaseModifier(retainedModifier)
            }
            return false
        }

        return true
    }

    func release(_ shortcut: KeyboardShortcut) {
        if shortcut.modifiers.isEmpty,
           let standaloneModifier = ModifierKey.standalone(for: shortcut.keyCode) {
            releaseModifier(standaloneModifier)
            return
        }

        let keyCode = CGKeyCode(shortcut.keyCode)
        if let existingCount = keyCounts[keyCode] {
            if existingCount <= 1 {
                keyCounts.removeValue(forKey: keyCode)
                _ = eventPoster.postKeyEvent(keyCode: keyCode, keyDown: false, flags: currentFlags)
            } else {
                keyCounts[keyCode] = existingCount - 1
            }
        }

        for modifier in ModifierKey.allCases.reversed()
        where modifier.isEnabled(in: shortcut.modifiers) {
            releaseModifier(modifier)
        }
    }

    func releaseAll() {
        for keyCode in keyCounts.keys.sorted() {
            _ = eventPoster.postKeyEvent(keyCode: keyCode, keyDown: false, flags: currentFlags)
        }
        keyCounts.removeAll()

        for modifier in ModifierKey.allCases.reversed() {
            guard modifierCounts[modifier, default: 0] > 0 else {
                continue
            }
            modifierCounts[modifier] = 0
            _ = eventPoster.postKeyEvent(
                keyCode: modifier.keyCode,
                keyDown: false,
                flags: currentFlags
            )
        }
        modifierCounts.removeAll()
    }

    private var currentFlags: CGEventFlags {
        ModifierKey.allCases.reduce(into: CGEventFlags()) { flags, modifier in
            if modifierCounts[modifier, default: 0] > 0 {
                flags.insert(modifier.flag)
            }
        }
    }

    private func retainModifier(_ modifier: ModifierKey) -> Bool {
        let existingCount = modifierCounts[modifier, default: 0]
        modifierCounts[modifier] = existingCount + 1
        guard existingCount == 0 else {
            return true
        }

        guard eventPoster.postKeyEvent(
            keyCode: modifier.keyCode,
            keyDown: true,
            flags: currentFlags
        ) else {
            modifierCounts.removeValue(forKey: modifier)
            return false
        }
        return true
    }

    private func releaseModifier(_ modifier: ModifierKey) {
        guard let existingCount = modifierCounts[modifier] else {
            return
        }
        if existingCount > 1 {
            modifierCounts[modifier] = existingCount - 1
            return
        }

        modifierCounts.removeValue(forKey: modifier)
        _ = eventPoster.postKeyEvent(
            keyCode: modifier.keyCode,
            keyDown: false,
            flags: currentFlags
        )
    }
}

protocol SymbolResolving {
    func resolve(_ name: String) -> UnsafeMutableRawPointer?
}

final class DynamicSymbolResolver: SymbolResolving {
    private let handle = dlopen(nil, RTLD_LAZY)

    func resolve(_ name: String) -> UnsafeMutableRawPointer? {
        guard let handle else {
            return nil
        }
        return dlsym(handle, name)
    }
}

enum SystemAction: String {
    case missionControl = "com.apple.expose.awake"
    case appExpose = "com.apple.expose.front.awake"
    case showDesktop = "com.apple.showdesktop.awake"
    case launchpad = "com.apple.launchpad.toggle"
}

final class CoreDockClient {
    private typealias CoreDockFunction = @convention(c) (
        CFString,
        UnsafeMutableRawPointer?
    ) -> Void

    private let function: CoreDockFunction?

    static let shared = CoreDockClient()

    init(symbolResolver: SymbolResolving = DynamicSymbolResolver()) {
        if let symbol = symbolResolver.resolve("CoreDockSendNotification") {
            function = unsafeBitCast(symbol, to: CoreDockFunction.self)
        } else {
            function = nil
        }
    }

    var isAvailable: Bool {
        function != nil
    }

    func perform(_ action: SystemAction) -> Bool {
        guard let function else {
            return false
        }
        function(action.rawValue as CFString, nil)
        return true
    }
}

protocol KeyboardLayoutResolving {
    func shortcut(for character: Character) -> KeyboardShortcut?
}

private struct KeyboardLayoutData {
    let data: Data
    let keyboardType: UInt32
}

final class KeyboardLayoutResolver: KeyboardLayoutResolving {
    private var shortcutsByCharacter: [Character: KeyboardShortcut] = [:]
    private var observer: NSObjectProtocol?

    init() {
        rebuildFromCurrentInputSource()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildFromCurrentInputSource()
        }
    }

    init?(inputSourceID: String) {
        guard let layoutData = Self.layoutData(forInputSourceID: inputSourceID) else {
            return nil
        }
        rebuild(using: layoutData)
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func shortcut(for character: Character) -> KeyboardShortcut? {
        shortcutsByCharacter[Character(String(character).lowercased())]
    }

    private func rebuildFromCurrentInputSource() {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = Self.layoutData(for: inputSource) else {
            shortcutsByCharacter = [:]
            return
        }
        rebuild(using: layoutData)
    }

    private func rebuild(using layoutData: KeyboardLayoutData) {
        let modifierCandidates: [(state: UInt32, modifiers: KeyboardShortcut.ModifierFlags)] = [
            (0, .init()),
            (UInt32(shiftKey >> 8), .init(shift: true)),
            (UInt32(optionKey >> 8), .init(option: true)),
            (UInt32((shiftKey | optionKey) >> 8), .init(option: true, shift: true)),
        ]

        var rebuilt: [Character: KeyboardShortcut] = [:]
        layoutData.data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return
            }
            let keyboardLayout = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)

            for candidate in modifierCandidates {
                for keyCode in UInt16(0)..<UInt16(128) {
                    guard let character = Self.character(
                        keyboardLayout: keyboardLayout,
                        keyboardType: layoutData.keyboardType,
                        keyCode: keyCode,
                        modifierState: candidate.state
                    ) else {
                        continue
                    }
                    let normalized = Character(String(character).lowercased())
                    if rebuilt[normalized] == nil {
                        rebuilt[normalized] = KeyboardShortcut(
                            keyCode: keyCode,
                            modifiers: candidate.modifiers
                        )
                    }
                }
            }
        }
        shortcutsByCharacter = rebuilt
    }

    private static func layoutData(forInputSourceID inputSourceID: String) -> KeyboardLayoutData? {
        let filter = [
            kTISPropertyInputSourceID as String: inputSourceID,
        ] as CFDictionary
        guard let sourceList = TISCreateInputSourceList(filter, true) else {
            return nil
        }
        let sources = sourceList.takeRetainedValue() as NSArray
        guard let sourceObject = sources.firstObject else {
            return nil
        }
        let source = sourceObject as! TISInputSource
        return layoutData(for: source)
    }

    private static func layoutData(for inputSource: TISInputSource) -> KeyboardLayoutData? {
        guard let property = TISGetInputSourceProperty(
            inputSource,
            kTISPropertyUnicodeKeyLayoutData
        ) else {
            return nil
        }
        let data = unsafeBitCast(property, to: CFData.self) as Data
        return KeyboardLayoutData(
            data: data,
            keyboardType: UInt32(LMGetKbdType())
        )
    }

    private static func character(
        keyboardLayout: UnsafePointer<UCKeyboardLayout>,
        keyboardType: UInt32,
        keyCode: UInt16,
        modifierState: UInt32
    ) -> Character? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var actualLength = 0

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            modifierState,
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &actualLength,
            &characters
        )

        guard status == noErr, actualLength == 1 else {
            return nil
        }
        return Character(String(utf16CodeUnits: characters, count: actualLength))
    }
}

final class PresetActionExecutor {
    private let keyboardState: KeyboardStateCoordinator
    private let coreDock: CoreDockClient
    private let layoutResolver: KeyboardLayoutResolving

    init(
        keyboardState: KeyboardStateCoordinator,
        coreDock: CoreDockClient = .shared,
        layoutResolver: KeyboardLayoutResolving = KeyboardLayoutResolver()
    ) {
        self.keyboardState = keyboardState
        self.coreDock = coreDock
        self.layoutResolver = layoutResolver
    }

    func isAvailable(_ action: PresetAction) -> Bool {
        if action.isDockAction {
            return coreDock.isAvailable
        }
        return shortcut(for: action) != nil
    }

    func perform(_ action: PresetAction) -> Bool {
        if action.isDockAction {
            guard let systemAction = systemAction(for: action) else {
                return false
            }
            return coreDock.perform(systemAction)
        }

        if action == .screenshotTool,
           let screenshotURL = NSWorkspace.shared.urlForApplication(
               withBundleIdentifier: "com.apple.screenshot.launcher"
           ) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(
                at: screenshotURL,
                configuration: configuration
            )
            return true
        }

        guard let shortcut = shortcut(for: action) else {
            return false
        }
        return keyboardState.perform(shortcut)
    }

    private func systemAction(for action: PresetAction) -> SystemAction? {
        switch action {
        case .missionControl: return .missionControl
        case .appExpose: return .appExpose
        case .showDesktop: return .showDesktop
        case .launchpad: return .launchpad
        default: return nil
        }
    }

    private func shortcut(for action: PresetAction) -> KeyboardShortcut? {
        switch action {
        case .notificationCenter:
            return logicalShortcut("n", additionalModifiers: .init(function: true))
        case .spotlight:
            return KeyboardShortcut(keyCode: UInt16(kVK_Space), modifiers: .init(command: true))
        case .screenshotTool:
            return KeyboardShortcut(
                keyCode: UInt16(kVK_ANSI_5),
                modifiers: .init(command: true, shift: true)
            )
        case .fullscreenToggle:
            return logicalShortcut("f", additionalModifiers: .init(command: true, control: true))
        case .minimizeWindow:
            return logicalShortcut("m", additionalModifiers: .init(command: true))
        case .browserBack:
            return logicalShortcut("[", additionalModifiers: .init(command: true))
        case .browserForward:
            return logicalShortcut("]", additionalModifiers: .init(command: true))
        case .copy:
            return logicalShortcut("c", additionalModifiers: .init(command: true))
        case .paste:
            return logicalShortcut("v", additionalModifiers: .init(command: true))
        case .undo:
            return logicalShortcut("z", additionalModifiers: .init(command: true))
        case .lockScreen:
            return logicalShortcut("q", additionalModifiers: .init(command: true, control: true))
        case .appSwitcher:
            return KeyboardShortcut(keyCode: UInt16(kVK_Tab), modifiers: .init(command: true))
        case .missionControl, .appExpose, .showDesktop, .launchpad:
            return nil
        }
    }

    private func logicalShortcut(
        _ character: Character,
        additionalModifiers: KeyboardShortcut.ModifierFlags
    ) -> KeyboardShortcut? {
        guard var shortcut = layoutResolver.shortcut(for: character) else {
            return nil
        }
        shortcut.modifiers = shortcut.modifiers.merging(additionalModifiers)
        return shortcut
    }
}

final class SystemEventActionExecutor: EventActionExecuting {
    private let keyboardState: KeyboardStateCoordinator
    let presetExecutor: PresetActionExecutor

    init(
        keyboardState: KeyboardStateCoordinator = KeyboardStateCoordinator(),
        coreDock: CoreDockClient = .shared,
        layoutResolver: KeyboardLayoutResolving = KeyboardLayoutResolver()
    ) {
        self.keyboardState = keyboardState
        presetExecutor = PresetActionExecutor(
            keyboardState: keyboardState,
            coreDock: coreDock,
            layoutResolver: layoutResolver
        )
    }

    func performShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        keyboardState.perform(shortcut)
    }

    func pressHeldShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        keyboardState.press(shortcut)
    }

    func releaseHeldShortcut(_ shortcut: KeyboardShortcut) {
        keyboardState.release(shortcut)
    }

    func performPresetAction(_ action: PresetAction) -> Bool {
        presetExecutor.perform(action)
    }

    func releaseAllHeldInput() {
        keyboardState.releaseAll()
    }
}

private extension KeyboardShortcut.ModifierFlags {
    func merging(_ other: Self) -> Self {
        Self(
            command: command || other.command,
            option: option || other.option,
            control: control || other.control,
            shift: shift || other.shift,
            function: function || other.function
        )
    }
}
