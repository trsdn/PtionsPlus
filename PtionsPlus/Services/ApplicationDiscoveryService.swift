import AppKit
import Foundation

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let url: URL
    let icon: NSImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

final class ApplicationDiscoveryTask {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

final class ApplicationDiscoveryService {
    private let fileManager: FileManager
    private let searchRoots: [URL]
    private let includeRunningApplications: Bool
    private let injectedRunningApplications: [AppInfo]?

    init(
        fileManager: FileManager = .default,
        searchRoots: [URL]? = nil,
        includeRunningApplications: Bool = true,
        runningApplications: [AppInfo]? = nil
    ) {
        self.fileManager = fileManager
        self.searchRoots = searchRoots ?? Self.defaultSearchRoots(fileManager: fileManager)
        self.includeRunningApplications = includeRunningApplications
        injectedRunningApplications = runningApplications
    }

    @discardableResult
    func discover(
        completion: @escaping (Result<[AppInfo], Error>) -> Void
    ) -> ApplicationDiscoveryTask {
        let task = ApplicationDiscoveryTask()
        let runningApplications = injectedRunningApplications ?? (includeRunningApplications
            ? NSWorkspace.shared.runningApplications.compactMap { application -> AppInfo? in
                guard application.activationPolicy != .prohibited else {
                    return nil
                }
                guard let bundleIdentifier = application.bundleIdentifier,
                      let name = application.localizedName,
                      let url = application.bundleURL else {
                    return nil
                }
                return AppInfo(
                    id: bundleIdentifier,
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    url: url,
                    icon: application.icon
                )
            }
            : [])

        let workItem = DispatchWorkItem { [fileManager, searchRoots] in
            var applicationsByBundleIdentifier: [String: AppInfo] = [:]
            for application in runningApplications {
                if applicationsByBundleIdentifier[application.bundleIdentifier] == nil {
                    applicationsByBundleIdentifier[application.bundleIdentifier] = application
                }
            }
            var firstError: Error?

            for root in searchRoots where fileManager.fileExists(atPath: root.path) {
                guard !task.isCancelled else {
                    return
                }
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, error in
                        if firstError == nil {
                            firstError = error
                        }
                        return true
                    }
                ) else {
                    continue
                }

                for case let url as URL in enumerator {
                    guard !task.isCancelled else {
                        return
                    }
                    guard url.pathExtension.lowercased() == "app" else {
                        continue
                    }
                    enumerator.skipDescendants()
                    guard let app = Self.appInfo(for: url),
                          applicationsByBundleIdentifier[app.bundleIdentifier] == nil else {
                        continue
                    }
                    applicationsByBundleIdentifier[app.bundleIdentifier] = app
                }
            }

            let applications = applicationsByBundleIdentifier.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            DispatchQueue.main.async {
                guard !task.isCancelled else {
                    return
                }
                if applications.isEmpty, let firstError {
                    completion(.failure(firstError))
                } else {
                    completion(.success(applications))
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        return task
    }

    static func appInfo(for url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty else {
            return nil
        }

        let name =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return AppInfo(
            id: bundleIdentifier,
            name: name,
            bundleIdentifier: bundleIdentifier,
            url: url,
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }

    private static func defaultSearchRoots(fileManager: FileManager) -> [URL] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
        ]
        return roots
    }
}
