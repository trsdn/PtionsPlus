import Foundation

enum EventDisposition: Equatable {
    case passThrough
    case suppress
}

protocol MappingResolving {
    func resolvedMapping(
        for button: MouseButton,
        bundleIdentifier: String?,
        deviceID: String?
    ) -> ButtonMapping?
    func isButtonAvailable(_ button: MouseButton, deviceID: String?) -> Bool
}

protocol EventActionExecuting: AnyObject {
    func performShortcut(_ shortcut: KeyboardShortcut) -> Bool
    func pressHeldShortcut(_ shortcut: KeyboardShortcut) -> Bool
    func releaseHeldShortcut(_ shortcut: KeyboardShortcut)
    func performPresetAction(_ action: PresetAction) -> Bool
    func releaseAllHeldInput()
}

private struct ButtonPressKey: Hashable {
    let deviceID: String?
    let button: MouseButton
}

private struct ButtonPressState {
    var depth: Int
    let disposition: EventDisposition
    let heldShortcut: KeyboardShortcut?
}

final class EventStateMachine {
    private let mappingResolver: MappingResolving
    private let actionExecutor: EventActionExecuting
    private var activePresses: [ButtonPressKey: ButtonPressState] = [:]
    /// Preserves press order so an unattributed release can still be paired with
    /// the oldest matching press for that button.
    private var pressOrder: [ButtonPressKey] = []

    init(mappingResolver: MappingResolving, actionExecutor: EventActionExecuting) {
        self.mappingResolver = mappingResolver
        self.actionExecutor = actionExecutor
    }

    func handle(
        button: MouseButton,
        isDown: Bool,
        bundleIdentifier: String?,
        deviceID: String? = nil
    ) -> EventDisposition {
        if isDown {
            return handleDown(
                button: button,
                bundleIdentifier: bundleIdentifier,
                deviceID: deviceID
            )
        }
        return handleUp(button: button, deviceID: deviceID)
    }

    func stop() {
        for press in activePresses.values {
            if let shortcut = press.heldShortcut {
                actionExecutor.releaseHeldShortcut(shortcut)
            }
        }
        activePresses.removeAll()
        pressOrder.removeAll()
        actionExecutor.releaseAllHeldInput()
    }

    private func handleDown(
        button: MouseButton,
        bundleIdentifier: String?,
        deviceID: String?
    ) -> EventDisposition {
        let key = ButtonPressKey(deviceID: deviceID, button: button)
        if var existing = activePresses[key] {
            existing.depth += 1
            activePresses[key] = existing
            return existing.disposition
        }

        guard mappingResolver.isButtonAvailable(button, deviceID: deviceID),
            let mapping = mappingResolver.resolvedMapping(
                for: button,
                bundleIdentifier: bundleIdentifier,
                deviceID: deviceID
            ),
            mapping.isActive
        else {
            store(ButtonPressState(depth: 1, disposition: .passThrough, heldShortcut: nil), for: key)
            return .passThrough
        }

        let disposition: EventDisposition
        var heldShortcut: KeyboardShortcut?

        if let action = mapping.systemAction {
            disposition = actionExecutor.performPresetAction(action) ? .suppress : .passThrough
        } else if let shortcut = mapping.shortcut {
            if mapping.holdWhilePressed {
                if actionExecutor.pressHeldShortcut(shortcut) {
                    disposition = .suppress
                    heldShortcut = shortcut
                } else {
                    disposition = .passThrough
                }
            } else {
                disposition = actionExecutor.performShortcut(shortcut) ? .suppress : .passThrough
            }
        } else {
            disposition = .passThrough
        }

        store(
            ButtonPressState(depth: 1, disposition: disposition, heldShortcut: heldShortcut),
            for: key
        )
        return disposition
    }

    private func handleUp(button: MouseButton, deviceID: String?) -> EventDisposition {
        guard let key = matchingPressKey(for: button, deviceID: deviceID),
            var press = activePresses[key]
        else {
            return .passThrough
        }

        if press.depth > 1 {
            press.depth -= 1
            activePresses[key] = press
            return press.disposition
        }

        activePresses.removeValue(forKey: key)
        pressOrder.removeAll { $0 == key }
        if let shortcut = press.heldShortcut {
            actionExecutor.releaseHeldShortcut(shortcut)
        }
        return press.disposition
    }

    private func matchingPressKey(
        for button: MouseButton,
        deviceID: String?
    ) -> ButtonPressKey? {
        let exact = ButtonPressKey(deviceID: deviceID, button: button)
        if activePresses[exact] != nil {
            return exact
        }
        return pressOrder.first { $0.button == button }
    }

    private func store(_ state: ButtonPressState, for key: ButtonPressKey) {
        if activePresses[key] == nil {
            pressOrder.append(key)
        }
        activePresses[key] = state
    }
}

extension MappingStore: MappingResolving {
    func resolvedMapping(
        for button: MouseButton,
        bundleIdentifier: String?,
        deviceID: String?
    ) -> ButtonMapping? {
        guard isConfigurationUsable else {
            return nil
        }
        return runtimeMapping(
            for: button,
            bundleIdentifier: bundleIdentifier,
            deviceID: deviceID
        )
    }

    func isButtonAvailable(_ button: MouseButton, deviceID: String?) -> Bool {
        isConfigurationUsable
            && runtimeModel(forDeviceID: deviceID)
                .availableButtons
                .contains(button)
    }
}
