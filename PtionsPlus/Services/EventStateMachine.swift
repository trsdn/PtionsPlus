import Foundation

enum EventDisposition: Equatable {
    case passThrough
    case suppress
}

protocol MappingResolving {
    func resolvedMapping(for button: MouseButton, bundleIdentifier: String?) -> ButtonMapping?
    func isButtonAvailable(_ button: MouseButton) -> Bool
}

protocol EventActionExecuting: AnyObject {
    func performShortcut(_ shortcut: KeyboardShortcut) -> Bool
    func pressHeldShortcut(_ shortcut: KeyboardShortcut) -> Bool
    func releaseHeldShortcut(_ shortcut: KeyboardShortcut)
    func performPresetAction(_ action: PresetAction) -> Bool
    func releaseAllHeldInput()
}

private struct ButtonPressState {
    var depth: Int
    let disposition: EventDisposition
    let heldShortcut: KeyboardShortcut?
}

final class EventStateMachine {
    private let mappingResolver: MappingResolving
    private let actionExecutor: EventActionExecuting
    private var activePresses: [MouseButton: ButtonPressState] = [:]

    init(mappingResolver: MappingResolving, actionExecutor: EventActionExecuting) {
        self.mappingResolver = mappingResolver
        self.actionExecutor = actionExecutor
    }

    func handle(
        button: MouseButton,
        isDown: Bool,
        bundleIdentifier: String?
    ) -> EventDisposition {
        if isDown {
            return handleDown(button: button, bundleIdentifier: bundleIdentifier)
        }
        return handleUp(button: button)
    }

    func stop() {
        for press in activePresses.values {
            if let shortcut = press.heldShortcut {
                actionExecutor.releaseHeldShortcut(shortcut)
            }
        }
        activePresses.removeAll()
        actionExecutor.releaseAllHeldInput()
    }

    private func handleDown(
        button: MouseButton,
        bundleIdentifier: String?
    ) -> EventDisposition {
        if var existing = activePresses[button] {
            existing.depth += 1
            activePresses[button] = existing
            return existing.disposition
        }

        guard mappingResolver.isButtonAvailable(button),
              let mapping = mappingResolver.resolvedMapping(
                for: button,
                bundleIdentifier: bundleIdentifier
              ),
              mapping.isActive else {
            activePresses[button] = ButtonPressState(
                depth: 1,
                disposition: .passThrough,
                heldShortcut: nil
            )
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

        activePresses[button] = ButtonPressState(
            depth: 1,
            disposition: disposition,
            heldShortcut: heldShortcut
        )
        return disposition
    }

    private func handleUp(button: MouseButton) -> EventDisposition {
        guard var press = activePresses[button] else {
            return .passThrough
        }

        if press.depth > 1 {
            press.depth -= 1
            activePresses[button] = press
            return press.disposition
        }

        activePresses.removeValue(forKey: button)
        if let shortcut = press.heldShortcut {
            actionExecutor.releaseHeldShortcut(shortcut)
        }
        return press.disposition
    }
}

extension MappingStore: MappingResolving {
    func resolvedMapping(for button: MouseButton, bundleIdentifier: String?) -> ButtonMapping? {
        guard isConfigurationUsable else {
            return nil
        }
        return mapping(for: button, in: profileFor(bundleIdentifier: bundleIdentifier))
    }

    func isButtonAvailable(_ button: MouseButton) -> Bool {
        isConfigurationUsable && configuration.mouseModel.availableButtons.contains(button)
    }
}
