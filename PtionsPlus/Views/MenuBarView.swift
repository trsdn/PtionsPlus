import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var appMonitor: ActiveAppMonitor
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { store.configuration.isEnabled },
                set: { newValue in
                    store.configuration.isEnabled = newValue
                    store.save()
                    if newValue {
                        eventTapService.start()
                    } else {
                        eventTapService.stop()
                    }
                }
            )) {
                Text("Enabled")
            }

            Divider()

            if let appName = appMonitor.activeAppName {
                let profile = store.profileFor(bundleIdentifier: appMonitor.activeBundleIdentifier)
                Label("Active: \(profile.name)", systemImage: "app.badge")
                    .font(.caption)
                Text(appName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !accessibilityChecker.isTrusted {
                Divider()
                Button("Grant Accessibility Access...") {
                    accessibilityChecker.openAccessibilitySettings()
                }
                .foregroundStyle(.red)
            }

            Divider()

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit Ptions+") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(4)
    }
}
