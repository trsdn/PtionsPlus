import Combine
import Foundation

final class RuntimeServiceCoordinator {
    private let store: MappingStore
    private let accessibilityChecker: AccessibilityChecking
    private let eventTapService: EventTapService
    private var cancellables = Set<AnyCancellable>()
    private var promptedForCurrentEnable = false

    init(
        store: MappingStore,
        accessibilityChecker: AccessibilityChecking,
        eventTapService: EventTapService
    ) {
        self.store = store
        self.accessibilityChecker = accessibilityChecker
        self.eventTapService = eventTapService
    }

    func start() {
        guard cancellables.isEmpty else {
            return
        }

        Publishers.CombineLatest3(
            store.$configuration
                .map(\.isEnabled)
                .removeDuplicates(),
            store.$persistenceState
                .map(\.canUseConfiguration)
                .removeDuplicates(),
            accessibilityChecker.trustPublisher
                .removeDuplicates()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] enabled, configurationUsable, trusted in
            self?.reconcile(
                enabled: enabled,
                configurationUsable: configurationUsable,
                trusted: trusted
            )
        }
        .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        promptedForCurrentEnable = false
        eventTapService.stop()
    }

    func retry() {
        reconcile(
            enabled: store.configuration.isEnabled,
            configurationUsable: store.isConfigurationUsable,
            trusted: accessibilityChecker.isTrusted
        )
    }

    private func reconcile(
        enabled: Bool,
        configurationUsable: Bool,
        trusted: Bool
    ) {
        guard enabled, configurationUsable else {
            promptedForCurrentEnable = false
            if eventTapService.status != .stopped {
                eventTapService.stop()
            }
            return
        }

        guard trusted else {
            if eventTapService.status != .permissionDenied {
                eventTapService.markPermissionDenied()
            }
            if !promptedForCurrentEnable {
                promptedForCurrentEnable = true
                accessibilityChecker.promptIfNeeded()
            }
            return
        }

        promptedForCurrentEnable = false
        if !eventTapService.isRunning {
            _ = eventTapService.start()
        }
    }
}
