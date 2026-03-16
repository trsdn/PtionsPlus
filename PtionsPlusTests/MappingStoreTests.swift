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
        XCTAssertFalse(configuration.launchAtLogin)
        XCTAssertTrue(configuration.isEnabled)
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

    private func makeStore(configuration: AppConfiguration) -> MappingStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        tempURLs.append(url)
        return MappingStore(configuration: configuration, configURL: url)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected value to be present", file: file, line: line)
            fatalError("Required test value was nil")
        }
        return value
    }
}