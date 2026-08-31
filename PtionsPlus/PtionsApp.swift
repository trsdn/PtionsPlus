import Combine
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
            Image(
                systemName: appDelegate.store.configuration.isEnabled
                    ? Constants.menuBarIcon : Constants.menuBarIconDisabled
            )
            .accessibilityLabel(
                appDelegate.store.configuration.isEnabled
                    ? "Ptions+, enabled" : "Ptions+, disabled")
        }

        Window("Ptions+ Settings", id: "settings") {
            SettingsView(
                store: appDelegate.store,
                eventTapService: appDelegate.eventTapService,
                accessibilityChecker: appDelegate.accessibilityChecker,
                deviceService: appDelegate.deviceService
            )
        }
        .defaultSize(width: 600, height: 450)

        Window("About Ptions+", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = MappingStore.shared
    let accessibilityChecker = AccessibilityChecker()
    let appMonitor = ActiveAppMonitor()
    let deviceService = HIDMouseDeviceService()
    lazy var eventTapService = EventTapService(
        store: store,
        appMonitor: appMonitor,
        deviceAttributor: deviceService
    )
    lazy var runtimeCoordinator = RuntimeServiceCoordinator(
        store: store,
        accessibilityChecker: accessibilityChecker,
        eventTapService: eventTapService
    )
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var uiTestWindow: NSWindow?
    private var deviceNameCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info(
            "App launched. Trusted: \(self.accessibilityChecker.isTrusted, privacy: .public), enabled: \(self.store.configuration.isEnabled, privacy: .public)"
        )

        if isUITesting {
            showUITestWindow()
            return
        }

        guard !isRunningTests else {
            return
        }

        appMonitor.start()
        accessibilityChecker.startMonitoring()
        deviceService.start()
        observeDeviceNames()
        runtimeCoordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeCoordinator.stop()
        deviceNameCancellable = nil
        deviceService.stop()
        accessibilityChecker.stopMonitoring()
        appMonitor.stop()
    }

    /// Keeps stored device labels aligned with the names macOS reports, so a
    /// renamed or re-paired mouse still shows up correctly in settings.
    private func observeDeviceNames() {
        deviceNameCancellable = deviceService.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                for device in devices where self.store.hasDeviceConfiguration(device.id) {
                    self.store.refreshDeviceName(id: device.id, name: device.name)
                }
            }
    }

    private func showUITestWindow() {
        let rootView = SettingsView(
            store: store,
            eventTapService: eventTapService,
            accessibilityChecker: accessibilityChecker,
            deviceService: deviceService
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
