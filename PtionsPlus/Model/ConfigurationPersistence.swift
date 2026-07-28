import Foundation

enum ConfigurationPersistenceState {
    case ready
    case needsRecovery([String])
    case loadFailed(String)
    case writeFailed(String)

    var canUseConfiguration: Bool {
        switch self {
        case .ready, .writeFailed:
            return true
        case .needsRecovery, .loadFailed:
            return false
        }
    }

    var blocksMutations: Bool {
        switch self {
        case .needsRecovery, .loadFailed:
            return true
        case .ready, .writeFailed:
            return false
        }
    }
}

enum ConfigurationRepositoryError: LocalizedError {
    case unsupportedSchema(Int)
    case invalidTopLevel

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This configuration uses unsupported schema version \(version)."
        case .invalidTopLevel:
            return "The configuration must contain a JSON object."
        }
    }
}

struct ConfigurationRecovery {
    let originalData: Data
    let repairedConfiguration: AppConfiguration
    let messages: [String]
}

enum ConfigurationLoadResult {
    case ready(AppConfiguration)
    case needsRecovery(ConfigurationRecovery)
    case failed(message: String, originalData: Data?)
}

struct ConfigurationRepository {
    let url: URL
    var fileManager: FileManager = .default

    func load() -> ConfigurationLoadResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return .ready(.empty)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .failed(message: "Could not read config.json: \(error.localizedDescription)", originalData: nil)
        }

        do {
            let schemaVersion = try Self.schemaVersion(in: data)
            guard schemaVersion <= AppConfiguration.currentSchemaVersion else {
                throw ConfigurationRepositoryError.unsupportedSchema(schemaVersion)
            }

            var configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
            configuration.schemaVersion = AppConfiguration.currentSchemaVersion

            let validation = ConfigurationValidator.validate(configuration)
            guard !validation.isValid else {
                return .ready(configuration)
            }

            return .needsRecovery(ConfigurationRecovery(
                originalData: data,
                repairedConfiguration: ConfigurationValidator.repair(configuration),
                messages: validation.messages
            ))
        } catch {
            return .failed(
                message: "Could not load config.json: \(error.localizedDescription)",
                originalData: data
            )
        }
    }

    func save(_ configuration: AppConfiguration) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var persistedConfiguration = configuration
        persistedConfiguration.schemaVersion = AppConfiguration.currentSchemaVersion

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(persistedConfiguration)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    func backup(_ data: Data) throws -> URL {
        let backupURL = try makeBackupURL()
        try data.write(to: backupURL, options: .atomic)
        return backupURL
    }

    @discardableResult
    func backupExistingFile() throws -> URL? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let backupURL = try makeBackupURL()
        try fileManager.copyItem(at: url, to: backupURL)
        return backupURL
    }

    private func makeBackupURL() throws -> URL {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = directory.appendingPathComponent(
            "\(url.lastPathComponent).backup-\(timestamp)-\(UUID().uuidString).json"
        )
        return backupURL
    }

    private static func schemaVersion(in data: Data) throws -> Int {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw ConfigurationRepositoryError.invalidTopLevel
        }

        if let number = dictionary["schemaVersion"] as? NSNumber {
            return number.intValue
        }
        return 1
    }
}

struct ConfigurationValidationResult {
    let messages: [String]

    var isValid: Bool {
        messages.isEmpty
    }
}

enum ConfigurationValidator {
    static func validate(_ configuration: AppConfiguration) -> ConfigurationValidationResult {
        var messages: [String] = []

        let defaultProfiles = configuration.profiles.filter(\.isDefault)
        if defaultProfiles.count != 1 {
            messages.append("Expected exactly one Default profile, found \(defaultProfiles.count).")
        }

        let duplicateProfileIDs = duplicates(in: configuration.profiles.map(\.id))
        if !duplicateProfileIDs.isEmpty {
            messages.append("Profile identifiers must be unique.")
        }

        let bundleIdentifiers = configuration.profiles.compactMap(\.bundleIdentifier)
        let duplicateBundleIdentifiers = duplicates(in: bundleIdentifiers)
        if !duplicateBundleIdentifiers.isEmpty {
            messages.append("App profiles must have unique bundle identifiers.")
        }

        var mappingIDs = Set<UUID>()
        for profile in configuration.profiles {
            let duplicateButtons = duplicates(in: profile.mappings.map(\.button))
            if !duplicateButtons.isEmpty {
                messages.append("\(profile.name) contains duplicate button mappings.")
            }

            for mapping in profile.mappings {
                if !mappingIDs.insert(mapping.id).inserted {
                    messages.append("Button mapping identifiers must be unique.")
                    break
                }
                if mapping.shortcut != nil && mapping.systemAction != nil {
                    messages.append("\(profile.name) contains a mapping with both a shortcut and preset action.")
                }
                if mapping.holdWhilePressed && mapping.shortcut == nil {
                    messages.append("\(profile.name) contains Push-to-Talk without a shortcut.")
                }
            }
        }

        if Set(configuration.globalButtons).count != configuration.globalButtons.count {
            messages.append("Global override buttons must be unique.")
        }

        return ConfigurationValidationResult(messages: Array(Set(messages)).sorted())
    }

    static func repair(_ configuration: AppConfiguration) -> AppConfiguration {
        var repaired = configuration
        repaired.schemaVersion = AppConfiguration.currentSchemaVersion
        repaired.globalButtons = Array(Set(configuration.globalButtons))
            .sorted { $0.rawValue < $1.rawValue }

        var usedProfileIDs = Set<UUID>()
        var defaultProfile: AppProfile?
        var appProfiles: [AppProfile] = []
        var appProfileIndices: [String: Int] = [:]

        for originalProfile in configuration.profiles {
            var profile = normalizedProfile(originalProfile)
            if !usedProfileIDs.insert(profile.id).inserted {
                profile.id = UUID()
                usedProfileIDs.insert(profile.id)
            }

            if profile.isDefault {
                if defaultProfile == nil {
                    defaultProfile = profile
                } else {
                    defaultProfile = merge(defaultProfile!, with: profile)
                }
                continue
            }

            guard let bundleIdentifier = profile.bundleIdentifier else {
                continue
            }

            if let existingIndex = appProfileIndices[bundleIdentifier] {
                appProfiles[existingIndex] = merge(appProfiles[existingIndex], with: profile)
            } else {
                appProfileIndices[bundleIdentifier] = appProfiles.count
                appProfiles.append(profile)
            }
        }

        repaired.profiles = [defaultProfile ?? AppProfile.makeDefault()] + appProfiles

        var usedMappingIDs = Set<UUID>()
        for profileIndex in repaired.profiles.indices {
            for mappingIndex in repaired.profiles[profileIndex].mappings.indices {
                if !usedMappingIDs.insert(repaired.profiles[profileIndex].mappings[mappingIndex].id).inserted {
                    repaired.profiles[profileIndex].mappings[mappingIndex].id = UUID()
                    usedMappingIDs.insert(repaired.profiles[profileIndex].mappings[mappingIndex].id)
                }
            }
        }

        return repaired
    }

    private static func normalizedProfile(_ profile: AppProfile) -> AppProfile {
        var normalized = profile
        var mappingsByButton: [MouseButton: ButtonMapping] = [:]

        for originalMapping in profile.mappings {
            var mapping = originalMapping
            if mapping.systemAction != nil {
                mapping.shortcut = nil
                mapping.holdWhilePressed = false
            } else if mapping.shortcut == nil {
                mapping.holdWhilePressed = false
            }

            if let existing = mappingsByButton[mapping.button] {
                if !existing.isActive && mapping.isActive {
                    mappingsByButton[mapping.button] = mapping
                }
            } else {
                mappingsByButton[mapping.button] = mapping
            }
        }

        normalized.mappings = mappingsByButton.values
            .sorted { $0.button.rawValue < $1.button.rawValue }
        return normalized
    }

    private static func merge(_ primary: AppProfile, with secondary: AppProfile) -> AppProfile {
        var merged = primary
        var mappingsByButton = Dictionary(
            uniqueKeysWithValues: primary.mappings.map { ($0.button, $0) }
        )

        for mapping in secondary.mappings {
            if let existing = mappingsByButton[mapping.button] {
                if !existing.isActive && mapping.isActive {
                    mappingsByButton[mapping.button] = mapping
                }
            } else {
                mappingsByButton[mapping.button] = mapping
            }
        }

        merged.mappings = mappingsByButton.values
            .sorted { $0.button.rawValue < $1.button.rawValue }
        return merged
    }

    private static func duplicates<Value: Hashable>(in values: [Value]) -> Set<Value> {
        var seen = Set<Value>()
        var duplicates = Set<Value>()
        for value in values where !seen.insert(value).inserted {
            duplicates.insert(value)
        }
        return duplicates
    }
}
