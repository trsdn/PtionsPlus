import Foundation
import Combine
import AppKit
import ApplicationServices

protocol AccessibilityChecking: AnyObject {
    var isTrusted: Bool { get }
    var trustPublisher: AnyPublisher<Bool, Never> { get }
    func promptIfNeeded()
}

final class AccessibilityChecker: ObservableObject, AccessibilityChecking {
    @Published private(set) var isTrusted: Bool = false

    private var timer: Timer?
    private let isTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        isTrusted = isTesting ? true : AXIsProcessTrusted()
    }

    var trustPublisher: AnyPublisher<Bool, Never> {
        $isTrusted.eraseToAnyPublisher()
    }

    func promptIfNeeded() {
        guard !isTesting else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func startMonitoring() {
        guard !isTesting else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTrust()
        }
        refreshTrust()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func openAccessibilitySettings() {
        guard !isTesting else { return }
        promptIfNeeded()

        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension.Privacy_Accessibility"
        ].compactMap(URL.init(string:))

        for url in urls {
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
        }
    }
}
