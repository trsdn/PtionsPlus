import XCTest
@testable import Ptions_

final class ConfigurationCompatibilityTests: XCTestCase {
    func testModifierFlagsDecodeDefaultsFunctionToFalse() throws {
        let data = Data(#"{"command":true,"option":false,"control":true,"shift":false}"#.utf8)

        let flags = try JSONDecoder().decode(KeyboardShortcut.ModifierFlags.self, from: data)

        XCTAssertTrue(flags.command)
        XCTAssertTrue(flags.control)
        XCTAssertFalse(flags.function)
        XCTAssertEqual(flags.displayComponents, ["⌃", "⌘"])
        XCTAssertFalse(flags.isEmpty)
    }

    func testButtonMappingDecodeDefaultsHoldWhilePressedToFalse() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","button":5,"shortcut":{"keyCode":3,"modifiers":{"command":true}}}"#.utf8)

        let mapping = try JSONDecoder().decode(ButtonMapping.self, from: data)

        XCTAssertEqual(mapping.button, .button5)
        XCTAssertEqual(mapping.shortcut, KeyboardShortcut(keyCode: 3, modifiers: .init(command: true)))
        XCTAssertFalse(mapping.holdWhilePressed)
    }

    func testAppConfigurationDecodeDefaultsMissingNewFields() throws {
        let data = Data(#"{"profiles":[{"id":"00000000-0000-0000-0000-000000000010","name":"Default","bundleIdentifier":null,"mappings":[{"id":"00000000-0000-0000-0000-000000000011","button":5,"systemAction":"mission_control"}]}]}"#.utf8)

        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)

        XCTAssertEqual(configuration.mouseModel, .mxMaster3)
        XCTAssertEqual(configuration.globalButtons, [])
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.schemaVersion, 1)
    }

    func testAppProfileDecodeDefaultsMissingIdentifiersAndMappings() throws {
        let data = Data(#"{"name":"Mail","bundleIdentifier":"com.apple.mail"}"#.utf8)

        let profile = try JSONDecoder().decode(AppProfile.self, from: data)

        XCTAssertEqual(profile.name, "Mail")
        XCTAssertEqual(profile.bundleIdentifier, "com.apple.mail")
        XCTAssertTrue(profile.mappings.isEmpty)
    }
}

final class MappingStoreTests: XCTestCase {
    private var tempURLs: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        for url in tempURLs {
            try? fileManager.removeItem(at: url)
        }
        tempURLs.removeAll()
        super.tearDown()
    }

    func testGlobalOverrideUsesDefaultMappingForAppProfile() {
        var defaultProfile = AppProfile.makeDefault()
        let defaultShortcut = KeyboardShortcut(keyCode: 3, modifiers: .init(function: true))
        let button = MouseButton.button5

        let defaultIndex = tryUnwrap(defaultProfile.mappings.firstIndex(where: { $0.button == button }))
        defaultProfile.mappings[defaultIndex].shortcut = defaultShortcut
        defaultProfile.mappings[defaultIndex].systemAction = nil

        let appProfile = AppProfile(
            name: "Mail",
            bundleIdentifier: "com.apple.mail",
            mappings: [ButtonMapping(button: button, systemAction: .copy)]
        )

        let store = makeStore(configuration: AppConfiguration(
            profiles: [defaultProfile, appProfile],
            mouseModel: .mxMaster4,
            globalButtons: [button]
        ))

        let resolved = store.mapping(for: button, in: appProfile)

        XCTAssertEqual(resolved?.shortcut, defaultShortcut)
        XCTAssertNil(resolved?.systemAction)
    }

    func testSetHoldWhilePressedOnlyChangesShortcutMappings() {
        let button = MouseButton.button6
        let appProfile = AppProfile(
            name: "Mail",
            bundleIdentifier: "com.apple.mail",
            mappings: [ButtonMapping(button: button, systemAction: .missionControl)]
        )
        let store = makeStore(configuration: AppConfiguration(profiles: [AppProfile.makeDefault(), appProfile]))

        store.setHoldWhilePressed(profileId: appProfile.id, button: button, enabled: true)

        let mapping = store.configuration.profiles[1].mappings[0]
        XCTAssertFalse(mapping.holdWhilePressed)
        XCTAssertEqual(mapping.systemAction, .missionControl)
    }

    func testUpdateMappingClearsHoldWhilePressedWhenShortcutIsRemoved() {
        let button = MouseButton.button6
        let shortcut = KeyboardShortcut(keyCode: 3, modifiers: .init(command: true))
        let appProfile = AppProfile(
            name: "Mail",
            bundleIdentifier: "com.apple.mail",
            mappings: [ButtonMapping(button: button, shortcut: shortcut, holdWhilePressed: true)]
        )
        let store = makeStore(configuration: AppConfiguration(profiles: [AppProfile.makeDefault(), appProfile]))

        store.updateMapping(profileId: appProfile.id, button: button, systemAction: .spotlight)

        let mapping = store.configuration.profiles[1].mappings[0]
        XCTAssertNil(mapping.shortcut)
        XCTAssertEqual(mapping.systemAction, .spotlight)
        XCTAssertFalse(mapping.holdWhilePressed)
    }

    func testAddProfileRejectsDuplicateBundleIdentifier() {
        let existing = AppProfile(
            name: "Mail",
            bundleIdentifier: "com.apple.mail",
            mappings: []
        )
        let duplicate = AppProfile(
            name: "Mail Copy",
            bundleIdentifier: "com.apple.mail",
            mappings: []
        )
        let store = makeStore(configuration: AppConfiguration(
            profiles: [AppProfile.makeDefault(), existing]
        ))

        XCTAssertFalse(store.addProfile(duplicate))
        XCTAssertEqual(store.configuration.profiles.count, 2)
    }

    func testCorruptConfigurationIsNotOverwrittenByMutation() throws {
        let url = makeTempURL()
        let originalData = Data(#"{"profiles":["#.utf8)
        try originalData.write(to: url)

        let store = MappingStore(configURL: url)
        let profile = AppProfile(name: "Mail", bundleIdentifier: "com.apple.mail", mappings: [])

        guard case .loadFailed = store.persistenceState else {
            return XCTFail("Expected load failure")
        }
        XCTAssertFalse(store.addProfile(profile))
        XCTAssertEqual(try Data(contentsOf: url), originalData)
    }

    func testFutureSchemaIsRejectedWithoutOverwritingFile() throws {
        let url = makeTempURL()
        let data = Data(#"{"schemaVersion":999,"profiles":[]}"#.utf8)
        try data.write(to: url)

        let store = MappingStore(configURL: url)

        guard case .loadFailed(let message) = store.persistenceState else {
            return XCTFail("Expected load failure")
        }
        XCTAssertTrue(message.contains("unsupported schema version 999"))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testInvalidConfigurationRequiresExplicitRepairAndCreatesBackup() throws {
        let url = makeTempURL()
        let defaultProfile = AppProfile.makeDefault()
        let first = AppProfile(name: "Mail", bundleIdentifier: "com.apple.mail", mappings: [])
        let second = AppProfile(name: "Mail Duplicate", bundleIdentifier: "com.apple.mail", mappings: [])
        let invalidConfiguration = AppConfiguration(profiles: [defaultProfile, first, second])
        let originalData = try JSONEncoder().encode(invalidConfiguration)
        try originalData.write(to: url)

        let store = MappingStore(configURL: url)

        guard case .needsRecovery(let messages) = store.persistenceState else {
            return XCTFail("Expected recovery state")
        }
        XCTAssertTrue(messages.contains(where: { $0.contains("unique bundle identifiers") }))
        XCTAssertTrue(store.applyProposedRepair())
        XCTAssertEqual(store.configuration.profiles.filter { $0.bundleIdentifier == "com.apple.mail" }.count, 1)

        let backups = try FileManager.default.contentsOfDirectory(
            at: url.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("\(url.lastPathComponent).backup-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), originalData)
        tempURLs.append(backups[0])
    }

    func testMissingDefaultProfileRequiresRecovery() throws {
        let url = makeTempURL()
        let appProfile = AppProfile(name: "Mail", bundleIdentifier: "com.apple.mail", mappings: [])
        let invalidConfiguration = AppConfiguration(profiles: [appProfile])
        try JSONEncoder().encode(invalidConfiguration).write(to: url)

        let store = MappingStore(configURL: url)

        guard case .needsRecovery = store.persistenceState else {
            return XCTFail("Expected recovery state")
        }
        XCTAssertFalse(store.isConfigurationUsable)
        XCTAssertTrue(store.applyProposedRepair())
        XCTAssertEqual(store.configuration.profiles.filter(\.isDefault).count, 1)
    }

    func testFailedWriteKeepsPublishedConfigurationUnchanged() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        tempURLs.append(directoryURL)

        let store = MappingStore(
            configuration: AppConfiguration.empty,
            configURL: directoryURL
        )
        let profile = AppProfile(name: "Mail", bundleIdentifier: "com.apple.mail", mappings: [])

        XCTAssertFalse(store.addProfile(profile))
        XCTAssertEqual(store.configuration.profiles.count, 1)
        guard case .writeFailed = store.persistenceState else {
            return XCTFail("Expected write failure")
        }
    }

    func testMouseModelChangeKeepsHiddenMappingsDormantAndRestorable() {
        var defaultProfile = AppProfile.makeDefault()
        let index = tryUnwrap(defaultProfile.mappings.firstIndex { $0.button == .button6 })
        defaultProfile.mappings[index].systemAction = .copy
        let store = makeStore(configuration: AppConfiguration(
            profiles: [defaultProfile],
            mouseModel: .mxMaster4,
            globalButtons: [.button6]
        ))

        let impact = store.modelChangeImpact(to: .generic3)

        XCTAssertEqual(impact.hiddenButtons, [.button5, .button6])
        XCTAssertEqual(impact.activeMappingCount, 2)
        XCTAssertEqual(impact.globalOverrideCount, 1)
        XCTAssertTrue(store.setMouseModel(.generic3))
        XCTAssertFalse(store.isButtonAvailable(.button6))
        XCTAssertNotNil(store.defaultProfile.mappings.first { $0.button == .button6 }?.systemAction)

        XCTAssertTrue(store.setMouseModel(.mxMaster4))
        XCTAssertTrue(store.isButtonAvailable(.button6))
        XCTAssertEqual(
            store.defaultProfile.mappings.first { $0.button == .button6 }?.systemAction,
            .copy
        )
    }

    func testResetRefusesToReplaceFileThatCannotBeBackedUp() throws {
        let url = makeTempURL()
        let originalData = Data("unreadable configuration".utf8)
        try originalData.write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: url.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        }

        let store = MappingStore(configURL: url)
        guard case .loadFailed = store.persistenceState else {
            return XCTFail("Expected load failure")
        }

        XCTAssertFalse(store.resetConfiguration())
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
        XCTAssertEqual(try Data(contentsOf: url), originalData)
    }

    private func makeStore(configuration: AppConfiguration) -> MappingStore {
        let url = makeTempURL()
        return MappingStore(configuration: configuration, configURL: url)
    }

    private func makeTempURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempURLs.append(directory)
        return directory.appendingPathComponent("config.json")
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected value to be present", file: file, line: line)
            fatalError("Required test value was nil")
        }
        return value
    }
}