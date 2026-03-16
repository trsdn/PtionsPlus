import SwiftUI

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
                    Text("Enable \"Override All App-Specifics\" on a Default button to force that Default mapping in every app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.configuration.mouseModel.availableButtons) { button in
                    let isGlobalOverride = !profile.isDefault && store.isGlobalButton(button)
                    let localMapping = profile.mappings.first(where: { $0.button == button })
                    let effectiveMapping = store.mapping(for: button, in: profile)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(button.displayName(for: store.configuration.mouseModel))
                                .frame(width: 140, alignment: .leading)

                            if store.isGlobalButton(button) {
                                Text(profile.isDefault ? "Global Override" : "Global Override Active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Spacer(minLength: 0)
                            }

                            Spacer()

                            if recordingButton == button {
                                ShortcutRecorderView { shortcut in
                                    store.updateMapping(profileId: profile.id, button: button, shortcut: shortcut)
                                    recordingButton = nil
                                } onCancel: {
                                    recordingButton = nil
                                }
                                .frame(width: 200, height: 30)
                            } else {
                                if effectiveMapping?.isActive == true {
                                    Text(effectiveMapping!.displayString)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .cornerRadius(6)

                                    if !isGlobalOverride {
                                        Button(role: .destructive) {
                                            store.updateMapping(profileId: profile.id, button: button)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    Text("Not assigned")
                                        .foregroundStyle(.secondary)
                                }

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
                                            Button("Record Custom Shortcut...") {
                                                recordingButton = button
                                            }
                                        }
                                    } label: {
                                        Text("Assign")
                                    }
                                    .menuStyle(.borderedButton)
                                    .fixedSize()
                                }
                            }
                        }

                        if profile.isDefault {
                            Toggle("Override All App-Specifics", isOn: Binding(
                                get: { store.isGlobalButton(button) },
                                set: { isEnabled in
                                    if isEnabled {
                                        let conflictCount = store.globalOverrideConflictCount(for: button)
                                        if conflictCount > 0 {
                                            pendingGlobalButton = button
                                            pendingConflictCount = conflictCount
                                        } else {
                                            store.setGlobalButton(button, enabled: true)
                                        }
                                    } else {
                                        store.setGlobalButton(button, enabled: false)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .font(.caption)
                        } else if isGlobalOverride {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This button is currently forced by the Default profile.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if localMapping?.isActive == true {
                                    Text("Your app-specific mapping is still saved, but it stays inactive until the Default global override is turned off.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
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
            Button("Use Default Everywhere") {
                store.setGlobalButton(button, enabled: true)
                pendingGlobalButton = nil
                pendingConflictCount = 0
            }
        } message: { button in
            Text("\(button.displayName(for: store.configuration.mouseModel)) is already configured in \(pendingConflictCount) app profile(s). Enabling \"Override All App-Specifics\" will force the Default mapping for this button until you turn the override off.")
        }
    }
}
