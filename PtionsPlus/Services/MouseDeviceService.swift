import AppKit
import Combine
import Foundation
import IOKit
import IOKit.hid
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "MouseDevices")

enum MouseInputMonitoringAccess: Equatable {
    case granted
    case denied
    case unknown

    var allowsAttribution: Bool {
        self == .granted
    }
}

/// Resolves which physical mouse produced a CoreGraphics button event.
protocol MouseDeviceAttributing: AnyObject {
    func device(forButtonNumber buttonNumber: Int64, isDown: Bool) -> ConnectedMouseDevice?
}

/// Discovers mice through IOKit and attributes button events to them.
///
/// CoreGraphics events carry no hardware identity, so raw HID button reports are
/// recorded on a dedicated run loop and matched against the events seen by the
/// event tap. Device discovery works with no extra permission; attribution needs
/// Input Monitoring and degrades to the shared configuration without it.
final class HIDMouseDeviceService: ObservableObject, MouseDeviceAttributing {
    @Published private(set) var connectedDevices: [ConnectedMouseDevice] = []
    @Published private(set) var accessState: MouseInputMonitoringAccess = .unknown

    private struct PendingKey: Hashable {
        let buttonNumber: Int
        let isDown: Bool
    }

    private struct ButtonReport {
        let device: ConnectedMouseDevice
        let timestamp: Date
    }

    /// How long a raw HID report stays eligible to explain a CoreGraphics event.
    private let attributionWindow: TimeInterval
    private let lock = NSLock()
    private var pendingReports: [PendingKey: [ButtonReport]] = [:]
    private var lastReportedDevice: ConnectedMouseDevice?

    private var manager: IOHIDManager?
    private var hidThread: Thread?
    private var hidRunLoop: CFRunLoop?
    private var isStarted = false

    init(attributionWindow: TimeInterval = 0.5) {
        self.attributionWindow = attributionWindow
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else {
            return
        }
        isStarted = true

        let manager = ensureManager()

        refreshConnectedDevices()
        updateAccessState()

        let thread = Thread { [weak self] in
            self?.runHIDLoop(manager: manager)
        }
        thread.name = "com.torsten.Ptions-Plus.hid"
        thread.qualityOfService = .userInteractive
        hidThread = thread
        thread.start()
    }

    func stop() {
        guard isStarted else {
            return
        }
        isStarted = false
        hidThread = nil

        lock.lock()
        let runLoop = hidRunLoop
        hidRunLoop = nil
        manager = nil
        pendingReports.removeAll()
        lastReportedDevice = nil
        lock.unlock()

        if let runLoop {
            CFRunLoopStop(runLoop)
        }
    }

    /// Asks macOS for Input Monitoring so button events can be attributed.
    func requestInputMonitoringAccess() {
        guard accessState != .granted else {
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            DispatchQueue.main.async {
                self?.updateAccessState()
            }
        }
    }

    func openInputMonitoringSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            )
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func refresh() {
        _ = ensureManager()
        refreshConnectedDevices()
        updateAccessState()
    }

    /// Creates the manager without opening it. Listing devices needs no
    /// permission, so settings can show the attached mice even when the input
    /// pipeline is not running.
    @discardableResult
    private func ensureManager() -> IOHIDManager {
        lock.lock()
        if let existing = manager {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let created = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(created, Self.deviceMatching as CFArray)

        lock.lock()
        if let existing = manager {
            lock.unlock()
            return existing
        }
        manager = created
        lock.unlock()
        return created
    }

    // MARK: - Attribution

    func device(forButtonNumber buttonNumber: Int64, isDown: Bool) -> ConnectedMouseDevice? {
        let key = PendingKey(buttonNumber: Int(buttonNumber), isDown: isDown)
        let now = Date()

        lock.lock()
        defer { lock.unlock() }

        var reports = pendingReports[key] ?? []
        reports.removeAll { now.timeIntervalSince($0.timestamp) > attributionWindow }

        guard let match = reports.first else {
            pendingReports[key] = []
            // The HID report may not have been observed, for example while Input
            // Monitoring is missing. Reusing the last known device keeps a paired
            // press and release on the same configuration.
            return lastReportedDevice
        }

        reports.removeFirst()
        pendingReports[key] = reports
        return match.device
    }

    // MARK: - HID plumbing

    private static let deviceMatching: [[String: Any]] = [
        [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
        ],
        [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer,
        ],
    ]

    private func runHIDLoop(manager: IOHIDManager) {
        guard let runLoop = CFRunLoopGetCurrent() else {
            return
        }
        lock.lock()
        // A stop() that lands before the thread starts must not be lost.
        let shouldRun = isStarted
        if shouldRun {
            hidRunLoop = runLoop
        }
        lock.unlock()

        guard shouldRun else {
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, hidDeviceChangedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, hidDeviceChangedCallback, context)
        IOHIDManagerSetInputValueMatchingMultiple(
            manager,
            [[kIOHIDElementUsagePageKey: kHIDPage_Button]] as CFArray
        )
        IOHIDManagerRegisterInputValueCallback(manager, hidInputValueCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            logger.notice(
                "IOHIDManagerOpen failed (\(String(format: "0x%08x", openResult), privacy: .public)); per-mouse mappings stay disabled"
            )
        }

        CFRunLoopRun()

        IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    fileprivate func handleDeviceListChanged() {
        refreshConnectedDevices()
    }

    fileprivate func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_Button) else {
            return
        }

        let usage = IOHIDElementGetUsage(element)
        guard usage >= 1 else {
            return
        }

        guard let device = Self.makeDevice(from: IOHIDElementGetDevice(element)) else {
            return
        }

        // HID button usages are one based while CoreGraphics button numbers start at zero.
        let key = PendingKey(buttonNumber: Int(usage) - 1, isDown: IOHIDValueGetIntegerValue(value) != 0)
        let report = ButtonReport(device: device, timestamp: Date())

        lock.lock()
        var reports = pendingReports[key] ?? []
        reports.append(report)
        if reports.count > 8 {
            reports.removeFirst(reports.count - 8)
        }
        pendingReports[key] = reports
        lastReportedDevice = device
        lock.unlock()
    }

    private func refreshConnectedDevices() {
        lock.lock()
        let manager = self.manager
        lock.unlock()

        guard let manager else {
            return
        }

        let devices = Self.enumerateDevices(in: manager)
        if Thread.isMainThread {
            applyConnectedDevices(devices)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyConnectedDevices(devices)
            }
        }
    }

    private func applyConnectedDevices(_ devices: [ConnectedMouseDevice]) {
        guard connectedDevices != devices else {
            return
        }
        connectedDevices = devices
    }

    private func updateAccessState() {
        let state: MouseInputMonitoringAccess
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            state = .granted
        case kIOHIDAccessTypeDenied:
            state = .denied
        default:
            state = .unknown
        }

        if Thread.isMainThread {
            accessState = state
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.accessState = state
            }
        }
    }

    private static func enumerateDevices(in manager: IOHIDManager) -> [ConnectedMouseDevice] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        // A single mouse exposes several HID interfaces, so collapse them by identity.
        var seen = Set<String>()
        var devices: [ConnectedMouseDevice] = []
        for hidDevice in deviceSet {
            guard let device = makeDevice(from: hidDevice),
                seen.insert(device.id).inserted
            else {
                continue
            }
            devices.append(device)
        }

        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func makeDevice(from hidDevice: IOHIDDevice) -> ConnectedMouseDevice? {
        // Devices without vendor and product identifiers, such as the built-in
        // trackpad, cannot be told apart reliably and are not configurable.
        guard let vendorID = intProperty(hidDevice, kIOHIDVendorIDKey),
            let productID = intProperty(hidDevice, kIOHIDProductIDKey)
        else {
            return nil
        }

        let identity = MouseDeviceIdentity(
            vendorID: vendorID,
            productID: productID,
            serialNumber: stringProperty(hidDevice, kIOHIDSerialNumberKey)
        )

        let productName = stringProperty(hidDevice, kIOHIDProductKey)
        let manufacturer = stringProperty(hidDevice, kIOHIDManufacturerKey)
        let name: String
        switch (manufacturer, productName) {
        case (let manufacturer?, let product?) where !product.localizedCaseInsensitiveContains(manufacturer):
            name = "\(manufacturer) \(product)"
        case (_, let product?):
            name = product
        case (let manufacturer?, nil):
            name = "\(manufacturer) Mouse"
        default:
            name = String(format: "Mouse %04x:%04x", vendorID, productID)
        }

        return ConnectedMouseDevice(identity: identity, name: name)
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func hidDeviceChangedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else {
        return
    }
    Unmanaged<HIDMouseDeviceService>.fromOpaque(context)
        .takeUnretainedValue()
        .handleDeviceListChanged()
}

private func hidInputValueCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard let context else {
        return
    }
    Unmanaged<HIDMouseDeviceService>.fromOpaque(context)
        .takeUnretainedValue()
        .handleInputValue(value)
}
