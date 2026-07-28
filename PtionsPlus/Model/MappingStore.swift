import Foundation
import Combine

struct MouseModelChangeImpact {
    let hiddenButtons: [MouseButton]
    let activeMappingCount: Int
    let globalOverrideCount: Int

    var requiresConfirmation: Bool {
        activeMappingCount > 0 || globalOverrideCount > 0
    }
}

final class MappingStore: ObservableObject {
    @Published private(set) var configuration: AppConfiguration
    @Published private(set) var persistenceState: ConfigurationPersistenceState = .ready

    private let repository: ConfigurationRepository
    private var pendingRecovery: ConfigurationRecovery?
    private var failedOriginalData: Data?

    static let shared = MappingStore()

    private init() {
        repository = ConfigurationRepository(url: Self.defaultConfigURL())
        configuration = .empty
        load()
    }

    init(configuration: AppConfiguration, configURL: URL) {
        self.configuration = configuration
        repository = ConfigurationRepository(url: configURL)
    }

    init(configURL: URL) {
        repository = ConfigurationRepository(url: configURL)
        configuration = .empty
        load()
    }

    private static func defaultConfigURL() -> URL {
        let processInfo = ProcessInfo.processInfo
        if let overridePath = processInfo.environment["PTIONS_CONFIG_URL"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Ptions+", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    var isConfigurationUsable: Bool {
        persistenceState.canUseConfiguration
    }

    func retryLoad() {
        load()
    }

    @discardableResult
    func applyProposedRepair() -> Bool {
        guard let pendingRecovery else {
            return false
        }

        do {
            try repository.backup(pendingRecovery.originalData)
            try repository.save(pendingRecovery.repairedConfiguration)
            configuration = pendingRecovery.repairedConfiguration
            persistenceState = .ready
            self.pendingRecovery = nil
            failedOriginalData = nil
            return true
        } catch {
            persistenceState = .needsRecovery(
                pendingRecovery.messages
                + ["Could not apply repaired configuration: \(error.localizedDescription)"]
            )
            return false
        }
    }

    @discardableResult
    func resetConfiguration() -> Bool {
        do {
            if let originalData = pendingRecovery?.originalData ?? failedOriginalData {
                try repository.backup(originalData)
            } else {
                try repository.backupExistingFile()
            }
            let resetConfiguration = AppConfiguration.empty
            try repository.save(resetConfiguration)
            configuration = resetConfiguration
            persistenceState = .ready
            pendingRecovery = nil
            failedOriginalData = nil
            return true
        } catch {
            let message = "Could not reset configuration: \(error.localizedDescription)"
            if let pendingRecovery {
                persistenceState = .needsRecovery(pendingRecovery.messages + [message])
            } else if failedOriginalData != nil {
                persistenceState = .loadFailed(message)
            } else {
                persistenceState = .writeFailed(message)
            }
            return false
        }
    }

    func dismissWriteError() {
        if case .writeFailed = persistenceState {
            persistenceState = .ready
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        commit { $0.isEnabled = enabled }
    }

    @discardableResult
    func setMouseModel(_ model: MouseModel) -> Bool {
        commit { $0.mouseModel = model }
    }

    func modelChangeImpact(to model: MouseModel) -> MouseModelChangeImpact {
        let hiddenButtons = configuration.mouseModel.availableButtons.filter {
            !model.availableButtons.contains($0)
        }
        let hiddenButtonSet = Set(hiddenButtons)
        let activeMappingCount = configuration.profiles.reduce(into: 0) { count, profile in
            count += profile.mappings.filter {
                hiddenButtonSet.contains($0.button) && $0.isActive
            }.count
        }
        let globalOverrideCount = configuration.globalButtons.filter {
            hiddenButtonSet.contains($0)
        }.count

        return MouseModelChangeImpact(
            hiddenButtons: hiddenButtons,
            activeMappingCount: activeMappingCount,
            globalOverrideCount: globalOverrideCount
        )
    }

    func profileFor(bundleIdentifier: String?) -> AppProfile {
        guard let bid = bundleIdentifier else {
            return defaultProfile
        }
        return configuration.profiles.first { $0.bundleIdentifier == bid } ?? defaultProfile
    }

    var defaultProfile: AppProfile {
        configuration.profiles.first { $0.isDefault } ?? AppProfile.makeDefault()
    }

    @discardableResult
    func addProfile(_ profile: AppProfile) -> Bool {
        if let bundleIdentifier = profile.bundleIdentifier,
           configuration.profiles.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return false
        }
        return commit { $0.profiles.append(profile) }
    }

    @discardableResult
    func updateProfile(_ profile: AppProfile) -> Bool {
        commit { candidate in
            guard let index = candidate.profiles.firstIndex(where: { $0.id == profile.id }) else {
                return
            }
            candidate.profiles[index] = profile
        }
    }

    @discardableResult
    func deleteProfile(_ profile: AppProfile) -> Bool {
        guard !profile.isDefault else { return false }
        return commit { $0.profiles.removeAll { $0.id == profile.id } }
    }

    @discardableResult
    func updateMapping(profileId: UUID, button: MouseButton, shortcut: KeyboardShortcut? = nil, systemAction: PresetAction? = nil) -> Bool {
        commit { candidate in
            guard let profileIndex = candidate.profiles.firstIndex(where: { $0.id == profileId }) else {
                return
            }
            if let mappingIndex = candidate.profiles[profileIndex].mappings.firstIndex(where: { $0.button == button }) {
                candidate.profiles[profileIndex].mappings[mappingIndex].shortcut = shortcut
                candidate.profiles[profileIndex].mappings[mappingIndex].systemAction = systemAction
                if shortcut == nil {
                    candidate.profiles[profileIndex].mappings[mappingIndex].holdWhilePressed = false
                }
                return
            }

            var mapping = ButtonMapping(button: button)
            mapping.shortcut = shortcut
            mapping.systemAction = systemAction
            if shortcut == nil {
                mapping.holdWhilePressed = false
            }
            candidate.profiles[profileIndex].mappings.append(mapping)
        }
    }

    @discardableResult
    func setHoldWhilePressed(profileId: UUID, button: MouseButton, enabled: Bool) -> Bool {
        commit { candidate in
            guard let profileIndex = candidate.profiles.firstIndex(where: { $0.id == profileId }),
                  let mappingIndex = candidate.profiles[profileIndex].mappings.firstIndex(where: { $0.button == button }),
                  candidate.profiles[profileIndex].mappings[mappingIndex].shortcut != nil else {
                return
            }

            candidate.profiles[profileIndex].mappings[mappingIndex].holdWhilePressed = enabled
        }
    }

    func isGlobalButton(_ button: MouseButton) -> Bool {
        configuration.globalButtons.contains(button)
    }

    @discardableResult
    func setGlobalButton(_ button: MouseButton, enabled: Bool) -> Bool {
        commit { candidate in
            if enabled {
                if !candidate.globalButtons.contains(button) {
                    candidate.globalButtons.append(button)
                    candidate.globalButtons.sort { $0.rawValue < $1.rawValue }
                }
            } else {
                candidate.globalButtons.removeAll { $0 == button }
            }
        }
    }

    func globalOverrideConflictCount(for button: MouseButton) -> Int {
        configuration.profiles
            .filter { !$0.isDefault }
            .filter {
                $0.mappings.first(where: { $0.button == button })?.isActive == true
            }
            .count
    }

    func mapping(for button: MouseButton, in profile: AppProfile) -> ButtonMapping? {
        if !profile.isDefault && isGlobalButton(button) {
            return defaultProfile.mappings.first(where: { $0.button == button })
        }
        return profile.mappings.first(where: { $0.button == button })
    }

    private func load() {
        switch repository.load() {
        case .ready(let configuration):
            self.configuration = configuration
            persistenceState = .ready
            pendingRecovery = nil
            failedOriginalData = nil
        case .needsRecovery(let recovery):
            configuration = recovery.repairedConfiguration
            persistenceState = .needsRecovery(recovery.messages)
            pendingRecovery = recovery
            failedOriginalData = nil
        case .failed(let message, let originalData):
            configuration = .empty
            persistenceState = .loadFailed(message)
            pendingRecovery = nil
            failedOriginalData = originalData
        }
    }

    @discardableResult
    private func commit(_ mutation: (inout AppConfiguration) -> Void) -> Bool {
        guard !persistenceState.blocksMutations else {
            return false
        }

        var candidate = configuration
        mutation(&candidate)
        candidate.schemaVersion = AppConfiguration.currentSchemaVersion

        let validation = ConfigurationValidator.validate(candidate)
        guard validation.isValid else {
            persistenceState = .writeFailed(validation.messages.joined(separator: " "))
            return false
        }

        do {
            try repository.save(candidate)
            configuration = candidate
            persistenceState = .ready
            return true
        } catch {
            persistenceState = .writeFailed("Could not save config.json: \(error.localizedDescription)")
            return false
        }
    }
}
