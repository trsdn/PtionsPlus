import Foundation
import Combine

final class MappingStore: ObservableObject {
    @Published var configuration: AppConfiguration

    private let configURL: URL

    static let shared = MappingStore()

    private init() {
        configURL = Self.defaultConfigURL()
        configuration = Self.loadConfiguration(from: configURL)
    }

    init(configuration: AppConfiguration, configURL: URL) {
        self.configuration = configuration
        self.configURL = configURL
    }

    private static func defaultConfigURL() -> URL {
        let processInfo = ProcessInfo.processInfo
        if let overridePath = processInfo.environment["PTIONS_CONFIG_URL"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logiDir = appSupport.appendingPathComponent("Ptions+", isDirectory: true)
        try? FileManager.default.createDirectory(at: logiDir, withIntermediateDirectories: true)
        return logiDir.appendingPathComponent("config.json")
    }

    private static func loadConfiguration(from url: URL) -> AppConfiguration {
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            return config
        }
        return .empty
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(configuration) else { return }
        try? data.write(to: configURL, options: .atomic)
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

    func addProfile(_ profile: AppProfile) {
        configuration.profiles.append(profile)
        save()
    }

    func updateProfile(_ profile: AppProfile) {
        if let idx = configuration.profiles.firstIndex(where: { $0.id == profile.id }) {
            configuration.profiles[idx] = profile
            save()
        }
    }

    func deleteProfile(_ profile: AppProfile) {
        guard !profile.isDefault else { return }
        configuration.profiles.removeAll { $0.id == profile.id }
        save()
    }

    func updateMapping(profileId: UUID, button: MouseButton, shortcut: KeyboardShortcut? = nil, systemAction: PresetAction? = nil) {
        guard let profileIdx = configuration.profiles.firstIndex(where: { $0.id == profileId }) else { return }
        if let mappingIdx = configuration.profiles[profileIdx].mappings.firstIndex(where: { $0.button == button }) {
            configuration.profiles[profileIdx].mappings[mappingIdx].shortcut = shortcut
            configuration.profiles[profileIdx].mappings[mappingIdx].systemAction = systemAction
            if shortcut == nil {
                configuration.profiles[profileIdx].mappings[mappingIdx].holdWhilePressed = false
            }
        } else {
            var mapping = ButtonMapping(button: button)
            mapping.shortcut = shortcut
            mapping.systemAction = systemAction
            if shortcut == nil {
                mapping.holdWhilePressed = false
            }
            configuration.profiles[profileIdx].mappings.append(mapping)
        }
        save()
    }

    func setHoldWhilePressed(profileId: UUID, button: MouseButton, enabled: Bool) {
        guard let profileIdx = configuration.profiles.firstIndex(where: { $0.id == profileId }),
              let mappingIdx = configuration.profiles[profileIdx].mappings.firstIndex(where: { $0.button == button }),
              configuration.profiles[profileIdx].mappings[mappingIdx].shortcut != nil else {
            return
        }

        configuration.profiles[profileIdx].mappings[mappingIdx].holdWhilePressed = enabled
        save()
    }

    func isGlobalButton(_ button: MouseButton) -> Bool {
        configuration.globalButtons.contains(button)
    }

    func setGlobalButton(_ button: MouseButton, enabled: Bool) {
        if enabled {
            if !configuration.globalButtons.contains(button) {
                configuration.globalButtons.append(button)
                configuration.globalButtons.sort { $0.rawValue < $1.rawValue }
            }
        } else {
            configuration.globalButtons.removeAll { $0 == button }
        }
        save()
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
}
