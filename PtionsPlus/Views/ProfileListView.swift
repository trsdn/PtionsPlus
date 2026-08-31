import SwiftUI

struct ProfileListView: View {
    @ObservedObject var store: MappingStore
    @Binding var selectedProfileId: UUID?
    @State private var showingAppPicker = false

    var body: some View {
        List(selection: $selectedProfileId) {
            Section("Default") {
                ForEach(store.editingConfiguration.profiles.filter { $0.isDefault }) { profile in
                    Label(profile.name, systemImage: "globe")
                        .accessibilityIdentifier("profile.default.\(profile.id.uuidString)")
                        .tag(profile.id)
                }
            }

            Section("App-Specific") {
                ForEach(store.editingConfiguration.profiles.filter { !$0.isDefault }) { profile in
                    Label(profile.name, systemImage: "app")
                        .accessibilityIdentifier("profile.app.\(profile.id.uuidString)")
                        .tag(profile.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                store.deleteProfile(profile)
                                if selectedProfileId == profile.id {
                                    selectedProfileId = nil
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAppPicker = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add app profile")
                .accessibilityHint("Choose an installed app to give it its own button mappings")
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                configuredBundleIdentifiers: Set(store.editingConfiguration.profiles.compactMap(\.bundleIdentifier))
            ) { bundleId, appName in
                let profile = AppProfile(
                    name: appName,
                    bundleIdentifier: bundleId,
                    mappings: MouseButton.allCases.map { ButtonMapping(button: $0) }
                )
                if store.addProfile(profile) {
                    selectedProfileId = profile.id
                    showingAppPicker = false
                }
            }
        }
        .onAppear {
            let profiles = store.editingConfiguration.profiles
            if selectedProfileId == nil
                || !profiles.contains(where: { $0.id == selectedProfileId })
            {
                selectedProfileId = store.defaultProfile.id
            }
        }
    }
}
