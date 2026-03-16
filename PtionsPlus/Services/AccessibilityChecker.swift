import Foundation
import Combine
import AppKit
import ApplicationServices

final class AccessibilityChecker: ObservableObject {
    @Published var isTrusted: Bool = false

    private var timer: Timer?
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    init() {
        isTrusted = isUITesting ? true : AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        guard !isUITesting else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func startPolling() {
        guard !isUITesting else { return }
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
        guard !isUITesting else { return }
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
