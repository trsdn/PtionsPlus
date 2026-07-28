import SwiftUI

private final class AppPickerViewModel: ObservableObject {
    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let discoveryService: ApplicationDiscoveryService
    private var discoveryTask: ApplicationDiscoveryTask?
    private var generation = UUID()

    init(discoveryService: ApplicationDiscoveryService = ApplicationDiscoveryService()) {
        self.discoveryService = discoveryService
    }

    func load() {
        stop()
        isLoading = true
        errorMessage = nil
        let currentGeneration = UUID()
        generation = currentGeneration
        discoveryTask = discoveryService.discover { [weak self] result in
            guard let self, self.generation == currentGeneration else {
                return
            }
            self.isLoading = false
            switch result {
            case .success(let apps):
                self.apps = apps
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        discoveryTask?.cancel()
        discoveryTask = nil
        generation = UUID()
        isLoading = false
    }
}

struct AppPickerView: View {
    let configuredBundleIdentifiers: Set<String>
    var onSelect: (_ bundleIdentifier: String, _ appName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AppPickerViewModel()
    @State private var searchText = ""
    @State private var manualSelectionError: String?

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty { return model.apps }
        return model.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Application")
                    .font(.headline)
                Spacer()
                Button("Choose App...") { chooseApplication() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if model.isLoading {
                ProgressView("Finding applications...")
                    .padding()
            }

            if let errorMessage = model.errorMessage ?? manualSelectionError {
                HStack {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Retry") { model.load() }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            List(filteredApps) { app in
                let isConfigured = configuredBundleIdentifiers.contains(app.bundleIdentifier)
                Button {
                    onSelect(app.bundleIdentifier, app.name)
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isConfigured {
                            Text("Configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isConfigured)
            }
        }
        .frame(width: 460, height: 520)
        .onAppear { model.load() }
        .onDisappear { model.stop() }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }
        guard let app = ApplicationDiscoveryService.appInfo(for: url) else {
            manualSelectionError = "The selected application has no bundle identifier."
            return
        }
        guard !configuredBundleIdentifiers.contains(app.bundleIdentifier) else {
            manualSelectionError = "\(app.name) already has a profile."
            return
        }
        manualSelectionError = nil
        onSelect(app.bundleIdentifier, app.name)
    }
}
