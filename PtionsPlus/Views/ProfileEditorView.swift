import SwiftUI
import Carbon.HIToolbox

struct ProfileEditorView: View {
    @ObservedObject var store: MappingStore
    let profile: AppProfile

    @State private var recordingButton: MouseButton?
    @State private var pendingGlobalButton: MouseButton?
    @State private var pendingConflictCount = 0

    private var actionCategories: [(String, [PresetAction])] {
        let grouped = Dictionary(grouping: PresetAction.allCases, by: \.category)
        let order = ["System", "macOS", "Window", "Navigation", "General"]
        return order.compactMap { cat in
            guard let actions = grouped[cat] else { return nil }
            return (cat, actions)
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(profile.name)
                        .font(.title2)
                        .bold()
                    if let bid = profile.bundleIdentifier {
                        Text(bid)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Button Mappings") {
                if profile.isDefault {
                    Text("Default defines fallback behavior. Turn on Override Apps for buttons that should ignore app-specific mappings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.configuration.mouseModel.availableButtons) { button in
                    ButtonMappingRow(
                        store: store,
                        profile: profile,
                        button: button,
                        actionCategories: actionCategories,
                        isRecording: recordingButton == button,
                        onStartRecording: { recordingButton = button },
                        onRecorded: { shortcut in
                            store.updateMapping(profileId: profile.id, button: button, shortcut: shortcut)
                            recordingButton = nil
                        },
                        onCancelRecording: { recordingButton = nil },
                        onRequestGlobalOverride: { conflictCount in
                            pendingGlobalButton = button
                            pendingConflictCount = conflictCount
                        }
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert(
            "Override App-Specific Mappings?",
            isPresented: Binding(
                get: { pendingGlobalButton != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingGlobalButton = nil
                        pendingConflictCount = 0
                    }
                }
            ),
            presenting: pendingGlobalButton
        ) { button in
            Button("Cancel", role: .cancel) {}
            Button("Override Apps") {
                store.setGlobalButton(button, enabled: true)
                pendingGlobalButton = nil
                pendingConflictCount = 0
            }
        } message: { button in
            Text("\(button.displayName(for: store.configuration.mouseModel)) is already configured in \(pendingConflictCount) app profile(s). Enabling Override Apps will force the Default mapping for this button until you turn it off.")
        }
    }

}

private struct ButtonMappingRow: View {
    @ObservedObject var store: MappingStore
    let profile: AppProfile
    let button: MouseButton
    let actionCategories: [(String, [PresetAction])]
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onRecorded: (KeyboardShortcut) -> Void
    let onCancelRecording: () -> Void
    let onRequestGlobalOverride: (Int) -> Void

    private var isGlobalOverride: Bool {
        !profile.isDefault && store.isGlobalButton(button)
    }

    private var localMapping: ButtonMapping? {
        profile.mappings.first(where: { $0.button == button })
    }

    private var effectiveMapping: ButtonMapping? {
        store.mapping(for: button, in: profile)
    }

    private var mappingStatusText: String {
        guard let effectiveMapping, effectiveMapping.isActive else { return "Not assigned" }
        return effectiveMapping.displayString
    }

    private var helperText: String {
        if isGlobalOverride {
            if localMapping?.isActive == true {
                return "Default currently overrides this button. Your local mapping is still saved."
            }
            return "Default currently overrides this button in this app."
        }

        guard let effectiveMapping, effectiveMapping.isActive else {
            return "No action assigned."
        }

        if effectiveMapping.shortcut != nil {
            return effectiveMapping.holdWhilePressed ? "Shortcut stays pressed while the mouse button is down." : "Shortcut runs when you press the mouse button."
        }

        return "Preset action runs when you press the mouse button."
    }

    private var showsPushToTalkToggle: Bool {
        guard let effectiveMapping else { return false }
        return effectiveMapping.shortcut != nil && !isGlobalOverride
    }

    private var showsStatusRow: Bool {
        store.isGlobalButton(button)
            || (effectiveMapping?.holdWhilePressed == true && effectiveMapping?.shortcut != nil)
            || (isGlobalOverride && localMapping?.isActive == true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(button.displayName(for: store.configuration.mouseModel))
                        .font(.body.weight(.semibold))

                    Text(helperText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isRecording {
                    ShortcutRecorderView(onRecord: onRecorded, onCancel: onCancelRecording)
                        .frame(width: 200, height: 30)
                } else {
                    HStack(spacing: 8) {
                        mappingValueChip(text: mappingStatusText, isAssigned: effectiveMapping?.isActive == true)

                        if !isGlobalOverride {
                            Menu {
                                ForEach(actionCategories, id: \.0) { category, actions in
                                    Section(category) {
                                        ForEach(actions) { action in
                                            Button(action.displayName) {
                                                store.updateMapping(profileId: profile.id, button: button, systemAction: action)
                                            }
                                        }
                                    }
                                }

                                Section {
                                    Button("Use Fn / Globe") {
                                        store.updateMapping(
                                            profileId: profile.id,
                                            button: button,
                                            shortcut: KeyboardShortcut(keyCode: UInt16(kVK_Function), modifiers: .init())
                                        )
                                    }

                                    Button("Record Custom Shortcut...") {
                                        onStartRecording()
                                    }
                                }
                            } label: {
                                Text(effectiveMapping?.isActive == true ? "Change" : "Assign")
                            }
                            .menuStyle(.borderedButton)
                            .fixedSize()
                        }

                        if effectiveMapping?.isActive == true {
                            Button {
                                store.updateMapping(profileId: profile.id, button: button)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if showsStatusRow {
                HStack(spacing: 8) {
                    if store.isGlobalButton(button) {
                        statusBadge(
                            title: profile.isDefault ? "Overrides Apps" : "Using Default",
                            systemImage: "globe"
                        )
                    }

                    if effectiveMapping?.holdWhilePressed == true, effectiveMapping?.shortcut != nil {
                        statusBadge(title: "Push-to-Talk", systemImage: "waveform")
                    }

                    if isGlobalOverride, localMapping?.isActive == true {
                        statusBadge(title: "Local Override Saved", systemImage: "tray.full")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if profile.isDefault {
                    optionRow(label: "Override Apps", description: "Use the Default mapping even when an app-specific profile exists.") {
                        Toggle("", isOn: Binding(
                            get: { store.isGlobalButton(button) },
                            set: { isEnabled in
                                if isEnabled {
                                    let conflictCount = store.globalOverrideConflictCount(for: button)
                                    if conflictCount > 0 {
                                        onRequestGlobalOverride(conflictCount)
                                    } else {
                                        store.setGlobalButton(button, enabled: true)
                                    }
                                } else {
                                    store.setGlobalButton(button, enabled: false)
                                }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

                if showsPushToTalkToggle, let effectiveMapping {
                    optionRow(label: "Push-to-Talk Mode", description: "Keep the shortcut pressed while you hold the mouse button.") {
                        Toggle("", isOn: Binding(
                            get: { effectiveMapping.holdWhilePressed },
                            set: { isEnabled in
                                store.setHoldWhilePressed(profileId: profile.id, button: button, enabled: isEnabled)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func mappingValueChip(text: String, isAssigned: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(isAssigned ? .primary : .secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
            )
    }

    @ViewBuilder
    private func optionRow<Control: View>(label: String, description: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            control()
        }
    }
}
