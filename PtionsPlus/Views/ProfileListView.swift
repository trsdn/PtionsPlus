import SwiftUI

struct ProfileListView: View {
    @ObservedObject var store: MappingStore
    @Binding var selectedProfileId: UUID?
    @State private var showingAppPicker = false

    var body: some View {
        List(selection: $selectedProfileId) {
            Section("Default") {
                ForEach(store.configuration.profiles.filter { $0.isDefault }) { profile in
                    Label(profile.name, systemImage: "globe")
                        .tag(profile.id)
                }
            }

            Section("App-Specific") {
                ForEach(store.configuration.profiles.filter { !$0.isDefault }) { profile in
                    Label(profile.name, systemImage: "app")
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
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView { bundleId, appName in
                let profile = AppProfile(
                    name: appName,
                    bundleIdentifier: bundleId,
                    mappings: MouseButton.allCases.map { ButtonMapping(button: $0) }
                )
                store.addProfile(profile)
                selectedProfileId = profile.id
                showingAppPicker = false
            }
        }
        .onAppear {
            if selectedProfileId == nil {
                selectedProfileId = store.defaultProfile.id
            }
        }
    }
}
