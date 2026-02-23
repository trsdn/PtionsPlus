import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var eventTapService: EventTapService
    @ObservedObject var accessibilityChecker: AccessibilityChecker

    var body: some View {
        TabView {
            ProfilesTab(store: store)
                .tabItem { Label("Profiles", systemImage: "person.2") }

            DebugMonitorView(eventTapService: eventTapService)
                .tabItem { Label("Debug", systemImage: "ant") }

            GeneralTab(store: store, accessibilityChecker: accessibilityChecker)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(minWidth: 550, minHeight: 400)
    }
}

private struct ProfilesTab: View {
    @ObservedObject var store: MappingStore
    @State private var selectedProfileId: UUID?

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            ProfileListView(store: store, selectedProfileId: $selectedProfileId)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
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
    @ObservedObject var accessibilityChecker: AccessibilityChecker

    private var modelCategories: [(String, [MouseModel])] {
        let grouped = Dictionary(grouping: MouseModel.allCases, by: \.category)
        return ["Logitech MX", "Logitech G", "Generic"].compactMap { cat in
            guard let models = grouped[cat] else { return nil }
            return (cat, models)
        }
    }

    var body: some View {
        Form {
            Section("Mouse Model") {
                Picker("Model", selection: Binding(
                    get: { store.configuration.mouseModel },
                    set: { newValue in
                        store.configuration.mouseModel = newValue
                        store.save()
                    }
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
                    Image(systemName: accessibilityChecker.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(accessibilityChecker.isTrusted ? .green : .red)
                    Text("Accessibility Access")
                    Spacer()
                    if !accessibilityChecker.isTrusted {
                        Button("Grant Access") {
                            accessibilityChecker.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section("Startup") {
                Toggle(isOn: Binding(
                    get: { store.configuration.launchAtLogin },
                    set: { newValue in
                        store.configuration.launchAtLogin = newValue
                        store.save()
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[Ptions+] Launch at login error: \(error)")
                        }
                    }
                )) {
                    Text("Launch at Login")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
