import AppKit
import Carbon.HIToolbox
import XCTest

@testable import Ptions_

final class MouseDeviceIdentityTests: XCTestCase {
    func testIdentityIncludesSerialNumberWhenAvailable() {
        let identity = MouseDeviceIdentity(vendorID: 0x046d, productID: 0xb034, serialNumber: "165D1821")

        XCTAssertEqual(identity.id, "046d:b034:165D1821")
        XCTAssertTrue(identity.isUniquePerDevice)
    }

    func testIdentityIgnoresBlankSerialNumber() {
        let identity = MouseDeviceIdentity(vendorID: 0x046d, productID: 0xb034, serialNumber: "   ")

        XCTAssertEqual(identity.id, "046d:b034")
        XCTAssertFalse(identity.isUniquePerDevice)
    }

    func testIdentityIsStableAcrossReconnects() {
        let first = MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: "A1")
        let second = MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: "A1")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.id, second.id)
    }

    func testIdentityRoundTripsThroughJSON() throws {
        let identity = MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: "A1")
        let data = try JSONEncoder().encode(identity)

        XCTAssertEqual(try JSONDecoder().decode(MouseDeviceIdentity.self, from: data), identity)
    }
}

final class MouseModelGuessTests: XCTestCase {
    func testBestGuessPrefersTheMostSpecificModel() {
        XCTAssertEqual(MouseModel.bestGuess(forProductName: "Logitech MX Master 3S"), .mxMaster3s)
        XCTAssertEqual(MouseModel.bestGuess(forProductName: "MX Master 3"), .mxMaster3)
        XCTAssertEqual(MouseModel.bestGuess(forProductName: "Logitech G502 HERO"), .g502)
    }

    func testBestGuessFallsBackToGenericForUnknownHardware() {
        XCTAssertEqual(MouseModel.bestGuess(forProductName: "Wireless Mouse"), .generic5)
        XCTAssertEqual(MouseModel.bestGuess(forProductName: ""), .generic5)
    }
}

final class SpacePresetActionTests: XCTestCase {
    func testSpacePresetsAreGroupedAndUseSystemDefaults() {
        XCTAssertEqual(PresetAction.nextSpace.category, "Spaces")
        XCTAssertEqual(PresetAction.previousSpace.category, "Spaces")
        XCTAssertTrue(PresetAction.nextSpace.usesDefaultSystemShortcut)
        XCTAssertTrue(PresetAction.previousSpace.usesDefaultSystemShortcut)
        XCTAssertFalse(PresetAction.nextSpace.isDockAction)
    }

    func testNextSpacePostsControlRightArrow() {
        let poster = StubKeyboardEventPoster()
        let executor = makeExecutor(poster: poster)

        XCTAssertTrue(executor.isAvailable(.nextSpace))
        XCTAssertTrue(executor.perform(.nextSpace))
        XCTAssertTrue(
            poster.events.contains {
                $0.keyCode == CGKeyCode(kVK_RightArrow) && $0.keyDown && $0.flags.contains(.maskControl)
            })
    }

    func testPreviousSpacePostsControlLeftArrow() {
        let poster = StubKeyboardEventPoster()
        let executor = makeExecutor(poster: poster)

        XCTAssertTrue(executor.perform(.previousSpace))
        XCTAssertTrue(
            poster.events.contains {
                $0.keyCode == CGKeyCode(kVK_LeftArrow) && $0.keyDown && $0.flags.contains(.maskControl)
            })
        XCTAssertTrue(
            poster.events.contains {
                $0.keyCode == CGKeyCode(kVK_LeftArrow) && !$0.keyDown
            })
    }

    private func makeExecutor(poster: StubKeyboardEventPoster) -> PresetActionExecutor {
        PresetActionExecutor(
            keyboardState: KeyboardStateCoordinator(eventPoster: poster),
            coreDock: CoreDockClient(symbolResolver: StubSymbolResolver()),
            layoutResolver: StubKeyboardLayoutResolver()
        )
    }
}

final class ShortcutRecorderCaptureTests: XCTestCase {
    func testControlArrowIsRecordedAndSuppressedWhileCapturing() throws {
        let capture = StubHotKeyCapture()
        let field = ShortcutRecorderField(hotKeyCapture: capture)
        var recorded: KeyboardShortcut?
        field.onRecord = { recorded = $0 }

        field.beginCapture()
        let handler = try XCTUnwrap(capture.handler)
        let event = try XCTUnwrap(makeKeyEvent(keyCode: UInt16(kVK_LeftArrow), flags: [.control]))

        XCTAssertEqual(handler(event), .suppress)
        XCTAssertEqual(recorded?.keyCode, UInt16(kVK_LeftArrow))
        XCTAssertTrue(try XCTUnwrap(recorded).modifiers.control)
        XCTAssertFalse(capture.isCapturing, "Capture must stop as soon as a shortcut is recorded")
    }

    func testEscapeCancelsAndStopsCapturing() throws {
        let capture = StubHotKeyCapture()
        let field = ShortcutRecorderField(hotKeyCapture: capture)
        var cancelled = false
        field.onCancel = { cancelled = true }

        field.beginCapture()
        let handler = try XCTUnwrap(capture.handler)
        let event = try XCTUnwrap(makeKeyEvent(keyCode: UInt16(kVK_Escape), flags: []))

        XCTAssertEqual(handler(event), .suppress)
        XCTAssertTrue(cancelled)
        XCTAssertFalse(capture.isCapturing)
    }

    func testCaptureStartsWithTheWindowAndStopsWhenRemoved() {
        let capture = StubHotKeyCapture()
        let field = ShortcutRecorderField(hotKeyCapture: capture)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )

        window.contentView?.addSubview(field)
        XCTAssertTrue(capture.isCapturing)

        field.removeFromSuperview()
        XCTAssertFalse(capture.isCapturing)
    }

    private func makeKeyEvent(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }
}

final class DeviceConfigurationSchemaTests: XCTestCase {
    func testSchemaVersionIsFour() {
        XCTAssertEqual(AppConfiguration.currentSchemaVersion, 4)
    }

    func testLegacyConfigurationDecodesWithoutDevices() throws {
        let data = Data(
            #"{"schemaVersion":3,"mouseModel":"mx_master_4","profiles":[{"name":"Default","bundleIdentifier":null,"mappings":[]}]}"#
                .utf8)

        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)

        XCTAssertTrue(configuration.devices.isEmpty)
        XCTAssertEqual(configuration.mouseModel, .mxMaster4)
        XCTAssertTrue(configuration.resolvedConfiguration(for: nil).isShared)
    }

    func testDeviceConfigurationRoundTripsThroughJSON() throws {
        let configuration = AppConfiguration(
            profiles: [AppProfile.makeDefault()],
            devices: [makeDeviceConfiguration(serial: "A1", model: .g502)]
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded.devices.count, 1)
        XCTAssertEqual(decoded.devices[0].model, .g502)
        XCTAssertEqual(decoded.devices[0].identity.serialNumber, "A1")
    }

    func testValidatorRejectsDuplicateDeviceConfigurations() {
        let device = makeDeviceConfiguration(serial: "A1", model: .g502)
        let configuration = AppConfiguration(
            profiles: [AppProfile.makeDefault()],
            devices: [device, device]
        )

        let result = ConfigurationValidator.validate(configuration)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.messages.contains("Each mouse may only have one configuration."))
        XCTAssertEqual(ConfigurationValidator.repair(configuration).devices.count, 1)
    }

    func testValidatorReportsAndRepairsBrokenDeviceScope() {
        var device = makeDeviceConfiguration(serial: "A1", model: .g502)
        device.profiles = []
        let configuration = AppConfiguration(
            profiles: [AppProfile.makeDefault()],
            devices: [device]
        )

        let result = ConfigurationValidator.validate(configuration)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(
            result.messages.contains { $0.hasPrefix("MX Master 3S: Expected exactly one Default profile") },
            "Expected device scoped message, got \(result.messages)"
        )

        let repaired = ConfigurationValidator.repair(configuration)
        XCTAssertTrue(ConfigurationValidator.validate(repaired).isValid)
        XCTAssertEqual(repaired.devices[0].profiles.filter(\.isDefault).count, 1)
    }

    func testSharedScopeMessagesStayUnprefixed() {
        let configuration = AppConfiguration(profiles: [])

        let result = ConfigurationValidator.validate(configuration)

        XCTAssertTrue(result.messages.contains("Expected exactly one Default profile, found 0."))
    }
}

final class MappingStoreDeviceTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
    }

    func testInputFromEachMouseUsesItsOwnMappings() {
        let device = makeDeviceConfiguration(serial: "A1", model: .mxMaster3s, button5Action: .copy)
        let store = makeStore(
            configuration: AppConfiguration(
                profiles: [AppProfile.makeDefault()],
                mouseModel: .mxMaster3,
                devices: [device]
            ))

        XCTAssertEqual(
            store.resolvedMapping(for: .button5, bundleIdentifier: nil, deviceID: device.id)?.systemAction,
            .copy
        )
        XCTAssertEqual(
            store.resolvedMapping(for: .button5, bundleIdentifier: nil, deviceID: nil)?.systemAction,
            .missionControl
        )
    }

    func testUnknownMouseFallsBackToSharedConfiguration() {
        let device = makeDeviceConfiguration(serial: "A1", model: .mxMaster3s, button5Action: .copy)
        let store = makeStore(
            configuration: AppConfiguration(
                profiles: [AppProfile.makeDefault()],
                devices: [device]
            ))

        XCTAssertEqual(
            store.resolvedMapping(for: .button5, bundleIdentifier: nil, deviceID: "ffff:ffff")?.systemAction,
            .missionControl
        )
    }

    func testAvailableButtonsFollowThePerDeviceModel() {
        var device = makeDeviceConfiguration(serial: "A1", model: .generic3)
        device.profiles = [AppProfile.makeDefault()]
        let store = makeStore(
            configuration: AppConfiguration(
                profiles: [AppProfile.makeDefault()],
                mouseModel: .mxMaster3,
                devices: [device]
            ))

        XCTAssertFalse(store.isButtonAvailable(.button5, deviceID: device.id))
        XCTAssertTrue(store.isButtonAvailable(.button5, deviceID: nil))
    }

    func testCreatingDeviceConfigurationSeedsFromSharedWithFreshIdentifiers() {
        let store = makeStore(configuration: .empty)
        let sharedProfileIDs = Set(store.editingConfiguration.profiles.map(\.id))

        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))

        let device = try? XCTUnwrap(store.deviceConfigurations.first)
        XCTAssertEqual(store.deviceConfigurations.count, 1)
        XCTAssertEqual(device?.model, .mxMaster3s)
        XCTAssertEqual(store.editingConfiguration.deviceID, device?.id)
        XCTAssertEqual(
            device?.profiles.first(where: \.isDefault)?.mappings.first { $0.button == .button5 }?.systemAction,
            .missionControl
        )
        for profile in device?.profiles ?? [] {
            XCTAssertFalse(sharedProfileIDs.contains(profile.id))
        }
        XCTAssertTrue(ConfigurationValidator.validate(store.configuration).isValid)
    }

    func testCreatingTheSameDeviceTwiceIsRejected() {
        let store = makeStore(configuration: .empty)

        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))
        XCTAssertFalse(store.createDeviceConfiguration(for: connectedDevice()))
        XCTAssertEqual(store.deviceConfigurations.count, 1)
    }

    func testEditsApplyOnlyToTheSelectedMouse() {
        let store = makeStore(configuration: .empty)
        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))
        let deviceID = store.editingConfiguration.deviceID

        let deviceDefault = store.defaultProfile
        XCTAssertTrue(
            store.updateMapping(
                profileId: deviceDefault.id,
                button: .back,
                systemAction: .nextSpace
            ))

        XCTAssertEqual(
            store.resolvedMapping(for: .back, bundleIdentifier: nil, deviceID: deviceID)?.systemAction,
            .nextSpace
        )
        XCTAssertNil(
            store.resolvedMapping(for: .back, bundleIdentifier: nil, deviceID: nil)?.systemAction
        )

        store.selectEditingDevice(nil)
        XCTAssertNil(store.defaultProfile.mappings.first { $0.button == .back }?.systemAction)
    }

    func testGlobalOverridesAreScopedPerMouse() {
        let store = makeStore(configuration: .empty)
        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))

        XCTAssertTrue(store.setGlobalButton(.back, enabled: true))
        XCTAssertTrue(store.isGlobalButton(.back))

        store.selectEditingDevice(nil)
        XCTAssertFalse(store.isGlobalButton(.back))
    }

    func testRemovingDeviceConfigurationReturnsToSharedMappings() {
        let store = makeStore(configuration: .empty)
        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))
        let deviceID = try? XCTUnwrap(store.editingConfiguration.deviceID)
        XCTAssertTrue(
            store.updateMapping(
                profileId: store.defaultProfile.id,
                button: .back,
                systemAction: .nextSpace
            ))

        XCTAssertTrue(store.removeDeviceConfiguration(id: try! XCTUnwrap(deviceID)))

        XCTAssertTrue(store.deviceConfigurations.isEmpty)
        XCTAssertNil(store.editingConfiguration.deviceID)
        XCTAssertNil(
            store.resolvedMapping(for: .back, bundleIdentifier: nil, deviceID: deviceID ?? "")?.systemAction
        )
    }

    func testDisconnectingOneMouseKeepsEveryStoredConfiguration() throws {
        let url = makeTempURL()
        let store = MappingStore(configuration: .empty, configURL: url)
        let first = ConnectedMouseDevice(
            identity: MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: "A1"),
            name: "Logitech MX Master 3S"
        )
        let second = ConnectedMouseDevice(
            identity: MouseDeviceIdentity(vendorID: 1133, productID: 49290, serialNumber: "B2"),
            name: "Logitech MX Anywhere 3"
        )

        XCTAssertTrue(store.createDeviceConfiguration(for: first))
        XCTAssertTrue(
            store.updateMapping(
                profileId: store.defaultProfile.id,
                button: .back,
                systemAction: .nextSpace
            ))
        XCTAssertTrue(store.createDeviceConfiguration(for: second))
        XCTAssertTrue(
            store.updateMapping(
                profileId: store.defaultProfile.id,
                button: .back,
                systemAction: .previousSpace
            ))

        // Reloading models a restart with only one of the mice attached.
        let reloaded = MappingStore(configURL: url)

        XCTAssertEqual(reloaded.deviceConfigurations.count, 2)
        XCTAssertEqual(
            reloaded.resolvedMapping(for: .back, bundleIdentifier: nil, deviceID: first.id)?.systemAction,
            .nextSpace
        )
        XCTAssertEqual(
            reloaded.resolvedMapping(for: .back, bundleIdentifier: nil, deviceID: second.id)?.systemAction,
            .previousSpace
        )
    }

    func testSelectingAnUnknownDeviceFallsBackToSharedEditing() {
        let store = makeStore(configuration: .empty)

        store.selectEditingDevice("ffff:ffff")

        XCTAssertTrue(store.editingConfiguration.isShared)
        XCTAssertTrue(store.setGlobalButton(.back, enabled: true))
        XCTAssertTrue(store.configuration.globalButtons.contains(.back))
    }

    func testDeviceNameIsRefreshedWhenMacOSReportsANewOne() {
        let store = makeStore(configuration: .empty)
        XCTAssertTrue(store.createDeviceConfiguration(for: connectedDevice()))
        let deviceID = try! XCTUnwrap(store.editingConfiguration.deviceID)

        XCTAssertTrue(store.refreshDeviceName(id: deviceID, name: "Desk Mouse"))
        XCTAssertEqual(store.deviceConfigurations.first?.name, "Desk Mouse")
        XCTAssertFalse(store.refreshDeviceName(id: deviceID, name: "Desk Mouse"))
        XCTAssertFalse(store.refreshDeviceName(id: deviceID, name: ""))
    }

    private func connectedDevice() -> ConnectedMouseDevice {
        ConnectedMouseDevice(
            identity: MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: "A1"),
            name: "Logitech MX Master 3S"
        )
    }

    private func makeStore(configuration: AppConfiguration) -> MappingStore {
        MappingStore(configuration: configuration, configURL: makeTempURL())
    }

    private func makeTempURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory.appendingPathComponent("config.json")
    }
}

final class EventStateMachineDeviceTests: XCTestCase {
    func testEachMouseKeepsItsOwnPressState() {
        let shortcut = KeyboardShortcut(keyCode: 5, modifiers: .init(command: true))
        let resolver = StubMappingResolver(
            mapping: ButtonMapping(button: .back, shortcut: shortcut, holdWhilePressed: true)
        )
        let executor = StubActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-a"),
            .suppress
        )
        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-b"),
            .suppress
        )
        XCTAssertEqual(executor.pressedShortcuts.count, 2)

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil, deviceID: "mouse-a"),
            .suppress
        )
        XCTAssertEqual(executor.releasedShortcuts.count, 1)

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil, deviceID: "mouse-b"),
            .suppress
        )
        XCTAssertEqual(executor.releasedShortcuts.count, 2)
    }

    func testMappingsAreResolvedForTheMouseThatSentTheEvent() {
        let resolver = StubMappingResolver(mapping: nil)
        resolver.mappingsByDevice["mouse-a"] = ButtonMapping(button: .back, systemAction: .nextSpace)
        resolver.mappingsByDevice["mouse-b"] = ButtonMapping(button: .back, systemAction: .previousSpace)
        let executor = StubActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        _ = stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-a")
        _ = stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil, deviceID: "mouse-a")
        _ = stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-b")
        _ = stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil, deviceID: "mouse-b")

        XCTAssertEqual(executor.performedPresets, [.nextSpace, .previousSpace])
    }

    func testUnattributedReleasePairsWithAnActivePress() {
        let shortcut = KeyboardShortcut(keyCode: 5, modifiers: .init(command: true))
        let resolver = StubMappingResolver(
            mapping: ButtonMapping(button: .back, shortcut: shortcut, holdWhilePressed: true)
        )
        let executor = StubActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        _ = stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-a")

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil, deviceID: nil),
            .suppress,
            "A release without device attribution must still end the active press"
        )
        XCTAssertEqual(executor.releasedShortcuts, [shortcut])
    }

    func testStopReleasesHeldShortcutsForEveryMouse() {
        let shortcut = KeyboardShortcut(keyCode: 5, modifiers: .init(command: true))
        let resolver = StubMappingResolver(
            mapping: ButtonMapping(button: .back, shortcut: shortcut, holdWhilePressed: true)
        )
        let executor = StubActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        _ = stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-a")
        _ = stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil, deviceID: "mouse-b")
        stateMachine.stop()

        XCTAssertEqual(executor.releasedShortcuts.count, 2)
        XCTAssertEqual(executor.releaseAllCallCount, 1)
    }
}

// MARK: - Helpers

private func makeDeviceConfiguration(
    serial: String,
    model: MouseModel,
    button5Action: PresetAction? = nil
) -> MouseDeviceConfiguration {
    var profile = AppProfile.makeDefault()
    if let button5Action,
        let index = profile.mappings.firstIndex(where: { $0.button == .button5 })
    {
        profile.mappings[index].systemAction = button5Action
    }

    return MouseDeviceConfiguration(
        identity: MouseDeviceIdentity(vendorID: 1133, productID: 45108, serialNumber: serial),
        name: "MX Master 3S",
        model: model,
        profiles: [profile]
    )
}

private struct StubSymbolResolver: SymbolResolving {
    func resolve(_ name: String) -> UnsafeMutableRawPointer? { nil }
}

private struct StubKeyboardLayoutResolver: KeyboardLayoutResolving {
    func shortcut(for character: Character) -> KeyboardShortcut? { nil }
}

private struct StubPostedEvent {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}

private final class StubKeyboardEventPoster: KeyboardEventPosting {
    private(set) var events: [StubPostedEvent] = []

    func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> Bool {
        events.append(StubPostedEvent(keyCode: keyCode, keyDown: keyDown, flags: flags))
        return true
    }
}

private final class StubHotKeyCapture: HotKeyCapturing {
    private(set) var isCapturing = false
    private(set) var handler: ((NSEvent) -> HotKeyCaptureDisposition)?

    @discardableResult
    func start(handler: @escaping (NSEvent) -> HotKeyCaptureDisposition) -> Bool {
        self.handler = handler
        isCapturing = true
        return true
    }

    func stop() {
        isCapturing = false
    }
}

private final class StubMappingResolver: MappingResolving {
    var mapping: ButtonMapping?
    var mappingsByDevice: [String: ButtonMapping] = [:]
    var availableButtons = Set(MouseButton.allCases)

    init(mapping: ButtonMapping?) {
        self.mapping = mapping
    }

    func resolvedMapping(
        for button: MouseButton,
        bundleIdentifier: String?,
        deviceID: String?
    ) -> ButtonMapping? {
        if let deviceID, let deviceMapping = mappingsByDevice[deviceID] {
            return deviceMapping
        }
        return mapping
    }

    func isButtonAvailable(_ button: MouseButton, deviceID: String?) -> Bool {
        availableButtons.contains(button)
    }
}

private final class StubActionExecutor: EventActionExecuting {
    var performedShortcuts: [KeyboardShortcut] = []
    var pressedShortcuts: [KeyboardShortcut] = []
    var releasedShortcuts: [KeyboardShortcut] = []
    var performedPresets: [PresetAction] = []
    var releaseAllCallCount = 0

    func performShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        performedShortcuts.append(shortcut)
        return true
    }

    func pressHeldShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        pressedShortcuts.append(shortcut)
        return true
    }

    func releaseHeldShortcut(_ shortcut: KeyboardShortcut) {
        releasedShortcuts.append(shortcut)
    }

    func performPresetAction(_ action: PresetAction) -> Bool {
        performedPresets.append(action)
        return true
    }

    func releaseAllHeldInput() {
        releaseAllCallCount += 1
    }
}
