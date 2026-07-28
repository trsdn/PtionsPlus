import AppKit
import Combine
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginManaging {
    var state: LaunchAtLoginState { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

struct SystemLaunchAtLoginService: LaunchAtLoginManaging {
    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

final class LaunchAtLoginViewModel: ObservableObject {
    @Published private(set) var state: LaunchAtLoginState
    @Published private(set) var errorMessage: String?

    private let service: LaunchAtLoginManaging
    private var cancellable: AnyCancellable?

    init(service: LaunchAtLoginManaging = SystemLaunchAtLoginService()) {
        self.service = service
        state = service.state
        cancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    var isEnabled: Bool {
        state == .enabled || state == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func refresh() {
        state = service.state
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
