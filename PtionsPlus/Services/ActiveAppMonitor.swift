import Foundation
import AppKit
import Combine

final class ActiveAppMonitor: ObservableObject {
    @Published var activeBundleIdentifier: String?
    @Published var activeAppName: String?

    private var cancellable: AnyCancellable?

    init() {
        let app = NSWorkspace.shared.frontmostApplication
        activeBundleIdentifier = app?.bundleIdentifier
        activeAppName = app?.localizedName
    }

    func start() {
        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.activeBundleIdentifier = app.bundleIdentifier
                self?.activeAppName = app.localizedName
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
