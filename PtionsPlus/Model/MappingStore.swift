import Combine
import Foundation

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
    /// Mouse whose mappings the settings UI is currently editing. `nil` edits the
    /// shared configuration that every unconfigured mouse falls back to.
    @Published private(set) var editingDeviceID: String?

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
        return
            appSupport
            .appendingPathComponent("Ptions+", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    var isConfigurationUsable: Bool {
        persistenceState.canUseConfiguration
    }

    // MARK: - Device scopes

    var deviceConfigurations: [MouseDeviceConfiguration] {
        configuration.devices
    }

    /// Configuration the settings UI edits. Falls back to the shared scope when
    /// the selected device no longer has its own entry.
    var editingConfiguration: ResolvedMouseConfiguration {
        configuration.resolvedConfiguration(for: resolvedEditingDeviceID)
    }

    private var resolvedEditingDeviceID: String? {
        guard let editingDeviceID,
            configuration.deviceConfiguration(withID: editingDeviceID) != nil
        else {
            return nil
        }
        return editingDeviceID
    }

    func selectEditingDevice(_ deviceID: String?) {
        guard editingDeviceID != deviceID else {
            return
        }
        editingDeviceID = deviceID
    }

    func hasDeviceConfiguration(_ deviceID: String) -> Bool {
        configuration.deviceConfiguration(withID: deviceID) != nil
    }

    /// Gives a mouse its own mappings, seeded from the shared configuration so the
    /// user starts from what they already had instead of an empty profile set.
    @discardableResult
    func createDeviceConfiguration(for device: ConnectedMouseDevice) -> Bool {
        guard configuration.deviceConfiguration(withID: device.id) == nil else {
            return false
        }

        let seeded = MouseDeviceConfiguration(
            identity: device.identity,
            name: device.name,
            model: MouseModel.bestGuess(forProductName: device.name),
            profiles: configuration.profiles.map { $0.copyWithNewIdentifiers() },
            globalButtons: configuration.globalButtons
        )

        let created = commit { $0.devices.append(seeded) }
        if created {
            editingDeviceID = seeded.id
        }
        return created
    }

    @discardableResult
    func removeDeviceConfiguration(id deviceID: String) -> Bool {
        guard configuration.deviceConfiguration(withID: deviceID) != nil else {
            return false
        }
        let removed = commit { $0.devices.removeAll { $0.id == deviceID } }
        if removed, editingDeviceID == deviceID {
            editingDeviceID = nil
        }
        return removed
    }

    /// Keeps the stored label in sync with the name macOS reports for the device.
    @discardableResult
    func refreshDeviceName(id deviceID: String, name: String) -> Bool {
        guard let existing = configuration.deviceConfiguration(withID: deviceID),
            existing.name != name,
            !name.isEmpty
        else {
            return false
        }
        return commit { candidate in
            guard let index = candidate.devices.firstIndex(where: { $0.id == deviceID }) else {
                return
            }
            candidate.devices[index].name = name
        }
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
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { currentModel, _, _ in
                currentModel = model
            }
        }
    }

    func modelChangeImpact(to model: MouseModel) -> MouseModelChangeImpact {
        let scope = editingConfiguration
        let hiddenButtons = scope.model.availableButtons.filter {
            !model.availableButtons.contains($0)
        }
        let hiddenButtonSet = Set(hiddenButtons)
        let activeMappingCount = scope.profiles.reduce(into: 0) { count, profile in
            count +=
                profile.mappings.filter {
                    hiddenButtonSet.contains($0.button) && $0.isActive
                }.count
        }
        let globalOverrideCount = scope.globalButtons.filter {
            hiddenButtonSet.contains($0)
        }.count

        return MouseModelChangeImpact(
            hiddenButtons: hiddenButtons,
            activeMappingCount: activeMappingCount,
            globalOverrideCount: globalOverrideCount
        )
    }

    func profileFor(bundleIdentifier: String?, deviceID: String? = nil) -> AppProfile {
        profileFor(
            bundleIdentifier: bundleIdentifier,
            in: configuration.resolvedConfiguration(for: deviceID)
        )
    }

    private func profileFor(
        bundleIdentifier: String?,
        in scope: ResolvedMouseConfiguration
    ) -> AppProfile {
        guard let bid = bundleIdentifier else {
            return defaultProfile(in: scope)
        }
        return scope.profiles.first { $0.bundleIdentifier == bid } ?? defaultProfile(in: scope)
    }

    var defaultProfile: AppProfile {
        defaultProfile(in: editingConfiguration)
    }

    private func defaultProfile(in scope: ResolvedMouseConfiguration) -> AppProfile {
        scope.profiles.first { $0.isDefault } ?? AppProfile.makeDefault()
    }

    @discardableResult
    func addProfile(_ profile: AppProfile) -> Bool {
        let scope = resolvedEditingDeviceID
        if let bundleIdentifier = profile.bundleIdentifier,
            editingConfiguration.profiles.contains(where: { $0.bundleIdentifier == bundleIdentifier })
        {
            return false
        }
        return commit { candidate in
            candidate.mutateScope(scope) { _, profiles, _ in
                profiles.append(profile)
            }
        }
    }

    @discardableResult
    func updateProfile(_ profile: AppProfile) -> Bool {
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { _, profiles, _ in
                guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
                    return
                }
                profiles[index] = profile
            }
        }
    }

    @discardableResult
    func deleteProfile(_ profile: AppProfile) -> Bool {
        guard !profile.isDefault else { return false }
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { _, profiles, _ in
                profiles.removeAll { $0.id == profile.id }
            }
        }
    }

    @discardableResult
    func updateMapping(
        profileId: UUID, button: MouseButton, shortcut: KeyboardShortcut? = nil, systemAction: PresetAction? = nil
    ) -> Bool {
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { _, profiles, _ in
                guard let profileIndex = profiles.firstIndex(where: { $0.id == profileId }) else {
                    return
                }
                if let mappingIndex = profiles[profileIndex].mappings.firstIndex(where: { $0.button == button }) {
                    profiles[profileIndex].mappings[mappingIndex].shortcut = shortcut
                    profiles[profileIndex].mappings[mappingIndex].systemAction = systemAction
                    if shortcut == nil {
                        profiles[profileIndex].mappings[mappingIndex].holdWhilePressed = false
                    }
                    return
                }

                var mapping = ButtonMapping(button: button)
                mapping.shortcut = shortcut
                mapping.systemAction = systemAction
                if shortcut == nil {
                    mapping.holdWhilePressed = false
                }
                profiles[profileIndex].mappings.append(mapping)
            }
        }
    }

    @discardableResult
    func setHoldWhilePressed(profileId: UUID, button: MouseButton, enabled: Bool) -> Bool {
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { _, profiles, _ in
                guard let profileIndex = profiles.firstIndex(where: { $0.id == profileId }),
                    let mappingIndex = profiles[profileIndex].mappings.firstIndex(where: { $0.button == button }),
                    profiles[profileIndex].mappings[mappingIndex].shortcut != nil
                else {
                    return
                }

                profiles[profileIndex].mappings[mappingIndex].holdWhilePressed = enabled
            }
        }
    }

    func isGlobalButton(_ button: MouseButton) -> Bool {
        editingConfiguration.globalButtons.contains(button)
    }

    @discardableResult
    func setGlobalButton(_ button: MouseButton, enabled: Bool) -> Bool {
        let scope = resolvedEditingDeviceID
        return commit { candidate in
            candidate.mutateScope(scope) { _, _, globalButtons in
                if enabled {
                    if !globalButtons.contains(button) {
                        globalButtons.append(button)
                        globalButtons.sort { $0.rawValue < $1.rawValue }
                    }
                } else {
                    globalButtons.removeAll { $0 == button }
                }
            }
        }
    }

    func globalOverrideConflictCount(for button: MouseButton) -> Int {
        editingConfiguration.profiles
            .filter { !$0.isDefault }
            .filter {
                $0.mappings.first(where: { $0.button == button })?.isActive == true
            }
            .count
    }

    func mapping(for button: MouseButton, in profile: AppProfile) -> ButtonMapping? {
        mapping(for: button, in: profile, scope: editingConfiguration)
    }

    private func mapping(
        for button: MouseButton,
        in profile: AppProfile,
        scope: ResolvedMouseConfiguration
    ) -> ButtonMapping? {
        if !profile.isDefault && scope.globalButtons.contains(button) {
            return defaultProfile(in: scope).mappings.first(where: { $0.button == button })
        }
        return profile.mappings.first(where: { $0.button == button })
    }

    // MARK: - Runtime resolution

    func runtimeMapping(
        for button: MouseButton,
        bundleIdentifier: String?,
        deviceID: String?
    ) -> ButtonMapping? {
        let scope = configuration.resolvedConfiguration(for: deviceID)
        return mapping(
            for: button,
            in: profileFor(bundleIdentifier: bundleIdentifier, in: scope),
            scope: scope
        )
    }

    func runtimeModel(forDeviceID deviceID: String?) -> MouseModel {
        configuration.resolvedConfiguration(for: deviceID).model
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
