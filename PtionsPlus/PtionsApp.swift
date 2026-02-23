import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "com.torsten.Ptions-Plus", category: "App")

@main
struct PtionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                store: appDelegate.store,
                appMonitor: appDelegate.appMonitor,
                eventTapService: appDelegate.eventTapService,
                accessibilityChecker: appDelegate.accessibilityChecker
            )
        } label: {
            Image(systemName: appDelegate.store.configuration.isEnabled ? Constants.menuBarIcon : Constants.menuBarIconDisabled)
        }

        Window("Ptions+ Settings", id: "settings") {
            SettingsView(
                store: appDelegate.store,
                eventTapService: appDelegate.eventTapService,
                accessibilityChecker: appDelegate.accessibilityChecker
            )
        }
        .defaultSize(width: 600, height: 450)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MappingStore.shared
    let accessibilityChecker = AccessibilityChecker()
    let appMonitor = ActiveAppMonitor()
    lazy var eventTapService = EventTapService(store: store, appMonitor: appMonitor)

    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("App launched. Trusted: \(self.accessibilityChecker.isTrusted), Enabled: \(self.store.configuration.isEnabled)")

        appMonitor.start()

        // Always try to start if trusted
        if accessibilityChecker.isTrusted {
            NSLog("Accessibility trusted, starting event tap")
            eventTapService.start()
            NSLog("Event tap running: \(self.eventTapService.isRunning)")
        } else {
            NSLog("Not trusted, prompting...")
            accessibilityChecker.promptIfNeeded()
            accessibilityChecker.startPolling()

            cancellable = accessibilityChecker.$isTrusted
                .removeDuplicates()
                .filter { $0 }
                .first()
                .sink { [weak self] _ in
                    guard let self else { return }
                    NSLog("Accessibility granted! Starting event tap")
                    self.accessibilityChecker.stopPolling()
                    self.eventTapService.start()
                    NSLog("Event tap running: \(self.eventTapService.isRunning)")
                }
        }
    }
}
