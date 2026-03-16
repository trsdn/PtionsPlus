import Foundation
import Combine
import AppKit
import ApplicationServices

final class AccessibilityChecker: ObservableObject {
    @Published var isTrusted: Bool = false

    private var timer: Timer?
    private let isTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        isTrusted = isTesting ? true : AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        guard !isTesting else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func startPolling() {
        guard !isTesting else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            if trusted != self?.isTrusted {
                DispatchQueue.main.async {
                    self?.isTrusted = trusted
                }
            }
        }
    }

    func stopPolling() {
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
}
