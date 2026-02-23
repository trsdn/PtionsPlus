import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var store: MappingStore
    let profile: AppProfile

    @State private var recordingButton: MouseButton?

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
                ForEach(store.configuration.mouseModel.availableButtons) { button in
                    HStack {
                        Text(button.displayName(for: store.configuration.mouseModel))
                            .frame(width: 120, alignment: .leading)

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
                            let mapping = profile.mappings.first(where: { $0.button == button })

                            if mapping?.isActive == true {
                                Text(mapping!.displayString)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.quaternary)
                                    .cornerRadius(6)

                                Button(role: .destructive) {
                                    store.updateMapping(profileId: profile.id, button: button)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("Not assigned")
                                    .foregroundStyle(.secondary)
                            }

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
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
