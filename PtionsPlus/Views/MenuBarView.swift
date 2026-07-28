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
                    store.setEnabled(newValue)
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

            if store.configuration.isEnabled {
                Label(eventTapStatusText, systemImage: eventTapStatusIcon)
                    .font(.caption)
                    .foregroundStyle(eventTapService.isRunning ? Color.secondary : Color.red)
                if case .failed = eventTapService.status {
                    Button("Retry Mouse Interception") {
                        eventTapService.start()
                    }
                }
            }

            if !store.isConfigurationUsable {
                Divider()
                Label("Configuration needs attention", systemImage: "exclamationmark.triangle.fill")
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

    private var eventTapStatusText: String {
        switch eventTapService.status {
        case .stopped: return "Mouse interception stopped"
        case .running: return "Mouse interception active"
        case .recovering: return "Recovering mouse interception"
        case .permissionDenied: return "Accessibility access required"
        case .failed(let message): return message
        }
    }

    private var eventTapStatusIcon: String {
        eventTapService.isRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
}
