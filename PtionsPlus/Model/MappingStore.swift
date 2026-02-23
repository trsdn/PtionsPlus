import Foundation
import Combine

final class MappingStore: ObservableObject {
    @Published var configuration: AppConfiguration

    private let configURL: URL

    static let shared = MappingStore()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logiDir = appSupport.appendingPathComponent("Ptions+", isDirectory: true)
        try? FileManager.default.createDirectory(at: logiDir, withIntermediateDirectories: true)
        configURL = logiDir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            configuration = config
        } else {
            configuration = .empty
        }
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
        } else {
            var mapping = ButtonMapping(button: button)
            mapping.shortcut = shortcut
            mapping.systemAction = systemAction
            configuration.profiles[profileIdx].mappings.append(mapping)
        }
        save()
    }
}
