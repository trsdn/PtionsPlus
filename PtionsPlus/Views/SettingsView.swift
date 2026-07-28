import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker

    var body: some View {
        VStack(spacing: 0) {
            ConfigurationStatusView(store: store)

            TabView {
                ProfilesTab(store: store)
                    .tabItem { Label("Profiles", systemImage: "person.2") }

                DebugMonitorView(eventTapService: eventTapService)
                    .tabItem { Label("Debug", systemImage: "ant") }

                GeneralTab(
                    store: store,
                    eventTapService: eventTapService,
                    accessibilityChecker: accessibilityChecker
                )
                    .tabItem { Label("General", systemImage: "gear") }
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .accessibilityIdentifier("settings.root")
    }
}

private struct ProfilesTab: View {
    @ObservedObject var store: MappingStore
    @State private var selectedProfileId: UUID?

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            ProfileListView(store: store, selectedProfileId: $selectedProfileId)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
                .accessibilityIdentifier("profiles.sidebar")
        } detail: {
            if let id = selectedProfileId,
               let profile = store.configuration.profiles.first(where: { $0.id == id }) {
                ProfileEditorView(store: store, profile: profile)
            } else {
                Text("Select a profile")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GeneralTab: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker
    @StateObject private var launchAtLogin = LaunchAtLoginViewModel()
    @State private var pendingMouseModel: MouseModel?
    @State private var pendingMouseModelImpact: MouseModelChangeImpact?

    private var modelCategories: [(String, [MouseModel])] {
        let grouped = Dictionary(grouping: MouseModel.allCases, by: \.category)
        return ["Logitech MX", "Logitech G", "Generic"].compactMap { category in
            guard let models = grouped[category] else { return nil }
            return (category, models)
        }
    }

    var body: some View {
        Form {
            Section("Mouse Model") {
                Picker("Model", selection: Binding(
                    get: { store.configuration.mouseModel },
                    set: selectMouseModel
                )) {
                    ForEach(modelCategories, id: \.0) { category, models in
                        Section(category) {
                            ForEach(models) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                    }
                }
                Text("\(store.configuration.mouseModel.availableButtons.count) configurable buttons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityChecker.isTrusted
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill")
                        .foregroundStyle(accessibilityChecker.isTrusted ? .green : .red)
                    Text("Accessibility Access")
                    Spacer()
                    if !accessibilityChecker.isTrusted {
                        Button("Grant Access") {
                            accessibilityChecker.openAccessibilitySettings()
                        }

                        if store.configuration.isEnabled {
                            HStack {
                                Image(systemName: eventTapService.isRunning
                                    ? "checkmark.circle.fill"
                                    : "exclamationmark.triangle.fill")
                                    .foregroundStyle(eventTapService.isRunning ? .green : .orange)
                                Text(eventTapService.isRunning
                                    ? "Mouse Interception Active"
                                    : "Mouse Interception Inactive")
                                Spacer()
                                if case .failed = eventTapService.status {
                                    Button("Retry") {
                                        eventTapService.start()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Section("Startup") {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: launchAtLogin.setEnabled
                )) {
                    Text("Launch at Login")
                }

                switch launchAtLogin.state {
                case .requiresApproval:
                    HStack {
                        Text("Approval is required in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") {
                            launchAtLogin.openSystemSettings()
                        }
                    }
                case .unavailable:
                    Text("Launch at Login is unavailable for this app installation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .disabled, .enabled:
                    EmptyView()
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .accessibilityIdentifier("general.form")
        .onAppear { launchAtLogin.refresh() }
        .alert(
            "Hide Active Button Mappings?",
            isPresented: Binding(
                get: { pendingMouseModel != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingMouseModel = nil
                        pendingMouseModelImpact = nil
                    }
                }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Change Model") {
                if let pendingMouseModel {
                    store.setMouseModel(pendingMouseModel)
                }
                pendingMouseModel = nil
                pendingMouseModelImpact = nil
            }
        } message: {
            if let impact = pendingMouseModelImpact {
                let buttons = impact.hiddenButtons
                    .map { $0.displayName(for: store.configuration.mouseModel) }
                    .joined(separator: ", ")
                Text(
                    "\(buttons) will be hidden. "
                    + "\(impact.activeMappingCount) active mapping(s) and "
                    + "\(impact.globalOverrideCount) global override(s) will remain saved but inactive."
                )
            }
        }
    }

    private func selectMouseModel(_ model: MouseModel) {
        let impact = store.modelChangeImpact(to: model)
        if impact.requiresConfirmation {
            pendingMouseModel = model
            pendingMouseModelImpact = impact
        } else {
            store.setMouseModel(model)
        }
    }
}

private struct ConfigurationStatusView: View {
    @ObservedObject var store: MappingStore

    var body: some View {
        switch store.persistenceState {
        case .ready:
            EmptyView()
        case .needsRecovery(let messages):
            statusBanner(
                title: "Configuration needs repair",
                message: messages.joined(separator: " "),
                primaryTitle: "Apply Repair",
                primaryAction: { store.applyProposedRepair() },
                secondaryTitle: "Reset",
                secondaryAction: { store.resetConfiguration() }
            )
        case .loadFailed(let message):
            statusBanner(
                title: "Configuration could not be loaded",
                message: message,
                primaryTitle: "Retry",
                primaryAction: { store.retryLoad() },
                secondaryTitle: "Reset",
                secondaryAction: { store.resetConfiguration() }
            )
        case .writeFailed(let message):
            statusBanner(
                title: "Configuration was not saved",
                message: message,
                primaryTitle: "Dismiss",
                primaryAction: { store.dismissWriteError() }
            )
        }
    }

    private func statusBanner(
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, role: .destructive, action: secondaryAction)
            }
            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.quaternary)
    }
}
