import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker
    @ObservedObject var deviceService: HIDMouseDeviceService

    var body: some View {
        VStack(spacing: 0) {
            ConfigurationStatusView(store: store)

            MouseScopePicker(store: store, deviceService: deviceService)

            TabView {
                ProfilesTab(store: store)
                    .tabItem { Label("Profiles", systemImage: "person.2") }

                DebugMonitorView(eventTapService: eventTapService)
                    .tabItem { Label("Debug", systemImage: "ant") }

                GeneralTab(
                    store: store,
                    eventTapService: eventTapService,
                    accessibilityChecker: accessibilityChecker,
                    deviceService: deviceService
                )
                    .tabItem { Label("General", systemImage: "gear") }
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .accessibilityIdentifier("settings.root")
        .onAppear { deviceService.refresh() }
    }
}

/// Chooses whether the settings below edit the shared configuration or the
/// mappings of one specific mouse.
private struct MouseScopePicker: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var deviceService: HIDMouseDeviceService

    private var connectedIDs: Set<String> {
        Set(deviceService.connectedDevices.map(\.id))
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "computermouse")
                .foregroundStyle(.secondary)

            Picker("Configuring", selection: Binding(
                get: { store.editingConfiguration.deviceID },
                set: { store.selectEditingDevice($0) }
            )) {
                Text("All Mice (Shared)").tag(String?.none)
                ForEach(store.deviceConfigurations) { device in
                    Text(connectedIDs.contains(device.id) ? device.name : "\(device.name) (Disconnected)")
                        .tag(String?.some(device.id))
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("settings.scopePicker")

            Text(store.editingConfiguration.isShared
                ? "Applies to every mouse without its own mappings."
                : "Applies only to this mouse.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4))
    }
}

private struct ProfilesTab: View {
    @ObservedObject var store: MappingStore
    @State private var selectedProfileId: UUID?

    /// Profile identifiers are scoped per mouse, so a selection made in one
    /// scope never resolves in another. Fall back to that scope's Default.
    private var resolvedProfile: AppProfile? {
        let profiles = store.editingConfiguration.profiles
        if let selectedProfileId,
           let match = profiles.first(where: { $0.id == selectedProfileId }) {
            return match
        }
        return profiles.first(where: \.isDefault)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            ProfileListView(store: store, selectedProfileId: $selectedProfileId)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
                .accessibilityIdentifier("profiles.sidebar")
        } detail: {
            if let profile = resolvedProfile {
                ProfileEditorView(store: store, profile: profile)
            } else {
                Text("Select a profile")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: store.editingDeviceID) { _ in
            selectedProfileId = store.defaultProfile.id
        }
    }
}

private struct GeneralTab: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker
    @ObservedObject var deviceService: HIDMouseDeviceService
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
                    get: { store.editingConfiguration.model },
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
                Text("\(store.editingConfiguration.model.availableButtons.count) configurable buttons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ConnectedMiceSection(store: store, deviceService: deviceService)

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
                    .map { $0.displayName(for: store.editingConfiguration.model) }
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

private struct ConnectedMiceSection: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var deviceService: HIDMouseDeviceService
    @State private var devicePendingRemoval: MouseDeviceConfiguration?

    /// Mice that were configured earlier but are not attached right now. Their
    /// mappings stay untouched so reconnecting restores them.
    private var disconnectedConfigured: [MouseDeviceConfiguration] {
        let connectedIDs = Set(deviceService.connectedDevices.map(\.id))
        return store.deviceConfigurations.filter { !connectedIDs.contains($0.id) }
    }

    var body: some View {
        Section("Connected Mice") {
            if deviceService.connectedDevices.isEmpty {
                Text("No mice detected. Built-in trackpads are not configurable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(deviceService.connectedDevices) { device in
                deviceRow(
                    name: device.name,
                    isConnected: true,
                    isUnique: device.identity.isUniquePerDevice,
                    configuration: store.deviceConfigurations.first { $0.id == device.id },
                    onConfigure: { store.createDeviceConfiguration(for: device) }
                )
                .accessibilityIdentifier("device.row.\(device.id)")
            }

            ForEach(disconnectedConfigured) { configuration in
                deviceRow(
                    name: configuration.name,
                    isConnected: false,
                    isUnique: configuration.identity.isUniquePerDevice,
                    configuration: configuration,
                    onConfigure: nil
                )
                .accessibilityIdentifier("device.row.\(configuration.id)")
            }

            if !deviceService.accessState.allowsAttribution {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "Input Monitoring is required to tell your mice apart.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)

                    Text("Without it every mouse uses the shared mappings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Request Access") {
                            deviceService.requestInputMonitoringAccess()
                        }
                        Button("Open Input Monitoring") {
                            deviceService.openInputMonitoringSettings()
                        }
                    }
                }
            }
        }
        .alert(
            "Delete Mappings for This Mouse?",
            isPresented: Binding(
                get: { devicePendingRemoval != nil },
                set: { if !$0 { devicePendingRemoval = nil } }
            ),
            presenting: devicePendingRemoval
        ) { configuration in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.removeDeviceConfiguration(id: configuration.id)
                devicePendingRemoval = nil
            }
        } message: { configuration in
            Text("\(configuration.name) will go back to the shared mappings. Its own mappings are deleted.")
        }
    }

    @ViewBuilder
    private func deviceRow(
        name: String,
        isConnected: Bool,
        isUnique: Bool,
        configuration: MouseDeviceConfiguration?,
        onConfigure: (() -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isConnected ? "computermouse.fill" : "computermouse")
                .foregroundStyle(isConnected ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(subtitle(isConnected: isConnected, isUnique: isUnique, hasConfiguration: configuration != nil))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let configuration {
                Button("Edit") {
                    store.selectEditingDevice(configuration.id)
                }
                Button("Use Shared") {
                    devicePendingRemoval = configuration
                }
            } else if let onConfigure {
                Button("Configure Separately", action: onConfigure)
            }
        }
    }

    private func subtitle(isConnected: Bool, isUnique: Bool, hasConfiguration: Bool) -> String {
        var parts: [String] = []
        parts.append(hasConfiguration ? "Own mappings" : "Uses shared mappings")
        if !isConnected {
            parts.append("Disconnected")
        }
        if !isUnique {
            parts.append("No serial number, identical models share these mappings")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

private struct ConfigurationStatusView: View {    @ObservedObject var store: MappingStore

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
