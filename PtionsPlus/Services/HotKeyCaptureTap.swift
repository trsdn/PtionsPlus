import AppKit
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "HotKeyCapture")

/// Result of inspecting a captured keyboard event.
enum HotKeyCaptureDisposition {
    case passThrough
    case suppress
}

/// Captures raw keyboard events ahead of the macOS symbolic hot key handler.
///
/// System shortcuts such as Control + Arrow (space switching) never reach the
/// responder chain, so a session event tap is the only way to record them.
protocol HotKeyCapturing: AnyObject {
    var isCapturing: Bool { get }
    @discardableResult
    func start(handler: @escaping (NSEvent) -> HotKeyCaptureDisposition) -> Bool
    func stop()
}

final class HotKeyCaptureTap: HotKeyCapturing {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((NSEvent) -> HotKeyCaptureDisposition)?

    /// Only suppresses input while the app owns the keyboard focus, so a stuck
    /// recorder can never swallow shortcuts for the rest of the system.
    private let isApplicationActive: () -> Bool

    init(isApplicationActive: @escaping () -> Bool = { NSApp?.isActive ?? false }) {
        self.isApplicationActive = isApplicationActive
    }

    deinit {
        stop()
    }

    var isCapturing: Bool {
        eventTap != nil
    }

    @discardableResult
    func start(handler: @escaping (NSEvent) -> HotKeyCaptureDisposition) -> Bool {
        self.handler = handler

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return CGEvent.tapIsEnabled(tap: eventTap)
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: hotKeyCaptureCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            logger.notice("Falling back to responder-based shortcut recording")
            self.handler = nil
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func stop() {
        handler = nil
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

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let handler,
            isApplicationActive(),
            let keyEvent = NSEvent(cgEvent: event)
        else {
            return Unmanaged.passUnretained(event)
        }

        switch handler(keyEvent) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return nil
        }
    }
}

private func hotKeyCaptureCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let tap = Unmanaged<HotKeyCaptureTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
