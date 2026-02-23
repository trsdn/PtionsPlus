import SwiftUI

struct AppPickerView: View {
    var onSelect: (_ bundleIdentifier: String, _ appName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var apps: [AppInfo] = []

    struct AppInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let bundleIdentifier: String
        let icon: NSImage?

        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }

        static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    var filteredApps: [AppInfo] {
        if searchText.isEmpty { return apps }
        return apps.filter {
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
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredApps) { app in
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
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear { loadApps() }
    }

    private func loadApps() {
        var seen = Set<String>()
        var result: [AppInfo] = []

        // Running apps
        for app in NSWorkspace.shared.runningApplications {
            guard let bid = app.bundleIdentifier,
                  let name = app.localizedName,
                  !bid.isEmpty,
                  !seen.contains(bid) else { continue }
            seen.insert(bid)
            result.append(AppInfo(id: bid, name: name, bundleIdentifier: bid, icon: app.icon))
        }

        // /Applications
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(atPath: "/Applications") {
            for item in items where item.hasSuffix(".app") {
                let path = "/Applications/\(item)"
                guard let bundle = Bundle(path: path),
                      let bid = bundle.bundleIdentifier,
                      !seen.contains(bid) else { continue }
                seen.insert(bid)
                let name = item.replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: path)
                result.append(AppInfo(id: bid, name: name, bundleIdentifier: bid, icon: icon))
            }
        }

        apps = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
