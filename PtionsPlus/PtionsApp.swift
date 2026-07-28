import SwiftUI
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
    lazy var runtimeCoordinator = RuntimeServiceCoordinator(
        store: store,
        accessibilityChecker: accessibilityChecker,
        eventTapService: eventTapService
    )
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var uiTestWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("App launched. Trusted: \(self.accessibilityChecker.isTrusted, privacy: .public), enabled: \(self.store.configuration.isEnabled, privacy: .public)")

        if isUITesting {
            showUITestWindow()
            return
        }

        guard !isRunningTests else {
            return
        }

        appMonitor.start()
        accessibilityChecker.startMonitoring()
        runtimeCoordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeCoordinator.stop()
        accessibilityChecker.stopMonitoring()
        appMonitor.stop()
    }

    private func showUITestWindow() {
        let rootView = SettingsView(
            store: store,
            eventTapService: eventTapService,
            accessibilityChecker: accessibilityChecker
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ptions+ UI Tests"
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        uiTestWindow = window
    }
}
