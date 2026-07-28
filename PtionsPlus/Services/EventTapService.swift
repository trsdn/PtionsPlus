import Combine
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "EventTap")

struct MouseButtonEvent {
    let buttonNumber: Int64
    let isDown: Bool
    let timestamp: Date
}

enum EventTapStatus: Equatable {
    case stopped
    case running
    case recovering
    case permissionDenied
    case failed(String)
}

final class EventDiagnosticsSubscription {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancel()
    }
}

protocol EventTapBackend: AnyObject {
    var isEnabled: Bool { get }
    func start(userInfo: UnsafeMutableRawPointer) -> Bool
    func enable() -> Bool
    func stop()
}

final class SystemEventTapBackend: EventTapBackend {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isEnabled: Bool {
        guard let eventTap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start(userInfo: UnsafeMutableRawPointer) -> Bool {
        if eventTap != nil {
            return enable()
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func enable() -> Bool {
        guard let eventTap else {
            return false
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

final class EventTapService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status: EventTapStatus = .stopped

    private let appMonitor: ActiveAppMonitor
    private let eventStateMachine: EventStateMachine
    private let backend: EventTapBackend
    private var diagnosticsSubscribers: [UUID: (MouseButtonEvent) -> Void] = [:]

    init(
        store: MappingStore,
        appMonitor: ActiveAppMonitor,
        actionExecutor: EventActionExecuting = SystemEventActionExecutor(),
        backend: EventTapBackend = SystemEventTapBackend()
    ) {
        self.appMonitor = appMonitor
        eventStateMachine = EventStateMachine(
            mappingResolver: store,
            actionExecutor: actionExecutor
        )
        self.backend = backend
    }

    @discardableResult
    func start() -> Bool {
        if backend.isEnabled {
            updateStatus(.running)
            return true
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard backend.start(userInfo: userInfo) else {
            logger.error("Failed to create or enable the event tap")
            updateStatus(.failed("Could not start mouse interception."))
            return false
        }

        logger.info("Event tap started")
        updateStatus(.running)
        return true
    }

    func stop() {
        eventStateMachine.stop()
        backend.stop()
        updateStatus(.stopped)
        logger.info("Event tap stopped")
    }

    func markPermissionDenied() {
        eventStateMachine.stop()
        backend.stop()
        updateStatus(.permissionDenied)
    }

    func subscribeToDiagnostics(
        _ subscriber: @escaping (MouseButtonEvent) -> Void
    ) -> EventDiagnosticsSubscription {
        let id = UUID()
        diagnosticsSubscribers[id] = subscriber
        return EventDiagnosticsSubscription { [weak self] in
            self?.diagnosticsSubscribers.removeValue(forKey: id)
        }
    }

    func recoverFromDisabledTap() {
        eventStateMachine.stop()
        updateStatus(.recovering)
        if backend.enable() {
            updateStatus(.running)
            logger.info("Event tap re-enabled")
            return
        }

        backend.stop()
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        if backend.start(userInfo: userInfo) {
            updateStatus(.running)
            logger.info("Event tap recreated")
        } else {
            updateStatus(.failed("Mouse interception stopped and could not be recovered."))
            logger.error("Event tap recovery failed")
        }
    }

    fileprivate func handleEvent(
        _ proxy: CGEventTapProxy,
        _ type: CGEventType,
        _ event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recoverFromDisabledTap()
            return Unmanaged.passUnretained(event)
        }

        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isDown = type == .otherMouseDown
        deliverDiagnostic(MouseButtonEvent(
            buttonNumber: buttonNumber,
            isDown: isDown,
            timestamp: Date()
        ))

        guard let button = MouseButton(rawValue: Int(buttonNumber)) else {
            return Unmanaged.passUnretained(event)
        }

        let disposition = processMouseButton(
            button: button,
            isDown: isDown,
            bundleIdentifier: appMonitor.activeBundleIdentifier
        )
        switch disposition {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return nil
        }
    }

    private func updateStatus(_ status: EventTapStatus) {
        self.status = status
        isRunning = status == .running
    }

    func processMouseButton(
        button: MouseButton,
        isDown: Bool,
        bundleIdentifier: String?
    ) -> EventDisposition {
        eventStateMachine.handle(
            button: button,
            isDown: isDown,
            bundleIdentifier: bundleIdentifier
        )
    }

    func deliverDiagnostic(_ event: MouseButtonEvent) {
        guard !diagnosticsSubscribers.isEmpty else {
            return
        }

        let subscribers = Array(diagnosticsSubscribers.values)
        if Thread.isMainThread {
            subscribers.forEach { $0(event) }
        } else {
            DispatchQueue.main.async {
                subscribers.forEach { $0(event) }
            }
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let service = Unmanaged<EventTapService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handleEvent(proxy, type, event)
}
