import Foundation
import CoreGraphics
import Combine
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "EventTap")

struct MouseButtonEvent {
    let buttonNumber: Int64
    let isDown: Bool
    let timestamp: Date
}

final class EventTapService: ObservableObject {
    @Published var isRunning = false
    @Published var lastEvent: MouseButtonEvent?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let store: MappingStore
    private let appMonitor: ActiveAppMonitor

    var onEvent: ((MouseButtonEvent) -> Void)?

    init(store: MappingStore, appMonitor: ActiveAppMonitor) {
        self.store = store
        self.appMonitor = appMonitor
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            NSLog("[Ptions+] Failed to create event tap. Is Accessibility enabled?")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        NSLog("[Ptions+] Event tap created and enabled successfully")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    fileprivate func handleEvent(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isDown = type == .otherMouseDown

        let mouseEvent = MouseButtonEvent(buttonNumber: buttonNumber, isDown: isDown, timestamp: Date())

        DispatchQueue.main.async {
            self.lastEvent = mouseEvent
            self.onEvent?(mouseEvent)
        }

        guard let mouseButton = MouseButton(rawValue: Int(buttonNumber)) else {
            NSLog("[Ptions+] Unknown button number: \(buttonNumber)")
            return Unmanaged.passUnretained(event)
        }

        let bid = appMonitor.activeBundleIdentifier
        let profile = store.profileFor(bundleIdentifier: bid)
        NSLog("[Ptions+] Button \(buttonNumber) \(isDown ? "DOWN" : "UP") | App: \(bid ?? "nil") | Profile: \(profile.name) | Mappings: \(profile.mappings.count)")

        guard let mapping = profile.mappings.first(where: { $0.button == mouseButton }),
              mapping.isActive else {
            NSLog("[Ptions+] No mapping for button \(buttonNumber)")
            return Unmanaged.passUnretained(event)
        }

        if isDown {
            if let action = mapping.systemAction {
                NSLog("[Ptions+] Action: \(action.displayName)")
                KeySimulator.performPresetAction(action)
            } else if let shortcut = mapping.shortcut {
                NSLog("[Ptions+] Shortcut: \(shortcut.displayString)")
                KeySimulator.simulateShortcut(shortcut)
            }
        }

        return nil
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handleEvent(proxy, type, event)
}
