import Carbon.HIToolbox
import Combine
import XCTest
@testable import Ptions_

final class EventStateMachineTests: XCTestCase {
    func testMouseUpUsesMouseDownDispositionAfterMappingChanges() {
        let resolver = FakeMappingResolver(mapping: ButtonMapping(
            button: .back,
            shortcut: KeyboardShortcut(keyCode: 3, modifiers: .init(command: true))
        ))
        let executor = FakeEventActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: true, bundleIdentifier: "app.a"),
            .suppress
        )
        resolver.mapping = nil
        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: false, bundleIdentifier: "app.b"),
            .suppress
        )
    }

    func testPassedMouseDownKeepsMouseUpPassedAfterMappingAppears() {
        let resolver = FakeMappingResolver(mapping: nil)
        let executor = FakeEventActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: true, bundleIdentifier: nil),
            .passThrough
        )
        resolver.mapping = ButtonMapping(button: .back, systemAction: .copy)
        XCTAssertEqual(
            stateMachine.handle(button: .back, isDown: false, bundleIdentifier: nil),
            .passThrough
        )
        XCTAssertTrue(executor.performedPresets.isEmpty)
    }

    func testHeldShortcutIsPressedOnceAcrossOverlappingDownEvents() {
        let shortcut = KeyboardShortcut(keyCode: 3, modifiers: .init(control: true))
        let resolver = FakeMappingResolver(mapping: ButtonMapping(
            button: .button5,
            shortcut: shortcut,
            holdWhilePressed: true
        ))
        let executor = FakeEventActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        XCTAssertEqual(stateMachine.handle(button: .button5, isDown: true, bundleIdentifier: nil), .suppress)
        XCTAssertEqual(stateMachine.handle(button: .button5, isDown: true, bundleIdentifier: nil), .suppress)
        XCTAssertEqual(executor.pressedShortcuts, [shortcut])

        XCTAssertEqual(stateMachine.handle(button: .button5, isDown: false, bundleIdentifier: nil), .suppress)
        XCTAssertTrue(executor.releasedShortcuts.isEmpty)
        XCTAssertEqual(stateMachine.handle(button: .button5, isDown: false, bundleIdentifier: nil), .suppress)
        XCTAssertEqual(executor.releasedShortcuts, [shortcut])
    }

    func testStopReleasesHeldShortcutsAndAllInput() {
        let shortcut = KeyboardShortcut(keyCode: 3, modifiers: .init(control: true))
        let resolver = FakeMappingResolver(mapping: ButtonMapping(
            button: .button5,
            shortcut: shortcut,
            holdWhilePressed: true
        ))
        let executor = FakeEventActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        _ = stateMachine.handle(button: .button5, isDown: true, bundleIdentifier: nil)
        stateMachine.stop()

        XCTAssertEqual(executor.releasedShortcuts, [shortcut])
        XCTAssertEqual(executor.releaseAllCallCount, 1)
    }

    func testUnavailableButtonPassesThroughWithoutExecutingAction() {
        let resolver = FakeMappingResolver(mapping: ButtonMapping(button: .button6, systemAction: .copy))
        resolver.availableButtons = [.middle, .back, .forward]
        let executor = FakeEventActionExecutor()
        let stateMachine = EventStateMachine(mappingResolver: resolver, actionExecutor: executor)

        XCTAssertEqual(
            stateMachine.handle(button: .button6, isDown: true, bundleIdentifier: nil),
            .passThrough
        )
        XCTAssertTrue(executor.performedPresets.isEmpty)
    }
}

final class KeyboardStateCoordinatorTests: XCTestCase {
    func testSharedModifierIsReleasedAfterLastShortcut() {
        let poster = RecordingKeyboardEventPoster()
        let coordinator = KeyboardStateCoordinator(eventPoster: poster)
        let first = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_A), modifiers: .init(control: true))
        let second = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_B), modifiers: .init(control: true))

        XCTAssertTrue(coordinator.press(first))
        XCTAssertTrue(coordinator.press(second))
        coordinator.release(first)

        XCTAssertEqual(poster.events.filter {
            $0.keyCode == CGKeyCode(kVK_Control) && !$0.keyDown
        }.count, 0)

        coordinator.release(second)
        XCTAssertEqual(poster.events.filter {
            $0.keyCode == CGKeyCode(kVK_Control) && $0.keyDown
        }.count, 1)
        XCTAssertEqual(poster.events.filter {
            $0.keyCode == CGKeyCode(kVK_Control) && !$0.keyDown
        }.count, 1)
    }

    func testReleaseAllBalancesActiveInput() {
        let poster = RecordingKeyboardEventPoster()
        let coordinator = KeyboardStateCoordinator(eventPoster: poster)
        let shortcut = KeyboardShortcut(keyCode: UInt16(kVK_ANSI_A), modifiers: .init(command: true))

        XCTAssertTrue(coordinator.press(shortcut))
        coordinator.releaseAll()

        XCTAssertTrue(poster.events.contains {
            $0.keyCode == CGKeyCode(kVK_ANSI_A) && !$0.keyDown
        })
        XCTAssertTrue(poster.events.contains {
            $0.keyCode == CGKeyCode(kVK_Command) && !$0.keyDown
        })
    }
}

final class EventTapServiceRecoveryTests: XCTestCase {
    func testDisabledTapReenablesExistingBackend() {
        let backend = FakeEventTapBackend()
        backend.enableResult = true
        let service = makeEventTapService(backend: backend)

        service.recoverFromDisabledTap()

        XCTAssertEqual(service.status, .running)
        XCTAssertEqual(backend.enableCallCount, 1)
        XCTAssertEqual(backend.startCallCount, 0)
    }

    func testDisabledTapFailureIsVisibleAfterRecreateFails() {
        let backend = FakeEventTapBackend()
        backend.enableResult = false
        backend.startResult = false
        let service = makeEventTapService(backend: backend)

        service.recoverFromDisabledTap()

        guard case .failed = service.status else {
            return XCTFail("Expected failed status")
        }
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(backend.stopCallCount, 1)
        XCTAssertEqual(backend.startCallCount, 1)
    }

    func testRecoveryReleasesHeldShortcutBeforeReenablingTap() {
        let shortcut = KeyboardShortcut(keyCode: 3, modifiers: .init(control: true))
        let profile = AppProfile(
            name: "Default",
            bundleIdentifier: nil,
            mappings: [ButtonMapping(
                button: .button5,
                shortcut: shortcut,
                holdWhilePressed: true
            )]
        )
        let store = MappingStore(
            configuration: AppConfiguration(
                profiles: [profile],
                mouseModel: .mxMaster3
            ),
            configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
        )
        let executor = FakeEventActionExecutor()
        let backend = FakeEventTapBackend()
        backend.enableResult = true
        let service = EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: executor,
            backend: backend
        )

        XCTAssertEqual(
            service.processMouseButton(
                button: .button5,
                isDown: true,
                bundleIdentifier: nil
            ),
            .suppress
        )
        service.recoverFromDisabledTap()

        XCTAssertEqual(executor.releasedShortcuts, [shortcut])
        XCTAssertEqual(executor.releaseAllCallCount, 1)
        XCTAssertEqual(service.status, .running)
    }

    private func makeEventTapService(backend: EventTapBackend) -> EventTapService {
        let store = MappingStore(
            configuration: .empty,
            configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
        )
        return EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: FakeEventActionExecutor(),
            backend: backend
        )
    }
}

final class RuntimeServiceCoordinatorTests: XCTestCase {
    func testDisabledStartupDoesNotPromptOrStartEventTap() {
        let store = makeStore(enabled: false)
        let accessibility = FakeAccessibilityChecker(isTrusted: false)
        let backend = FakeEventTapBackend()
        backend.startResult = true
        let service = EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: FakeEventActionExecutor(),
            backend: backend
        )
        let coordinator = RuntimeServiceCoordinator(
            store: store,
            accessibilityChecker: accessibility,
            eventTapService: service
        )

        coordinator.start()
        drainMainQueue()

        XCTAssertEqual(accessibility.promptCallCount, 0)
        XCTAssertEqual(backend.startCallCount, 0)
        coordinator.stop()
    }

    func testPermissionGrantAfterDisableDoesNotStartEventTap() {
        let store = makeStore(enabled: true)
        let accessibility = FakeAccessibilityChecker(isTrusted: false)
        let backend = FakeEventTapBackend()
        backend.startResult = true
        let service = EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: FakeEventActionExecutor(),
            backend: backend
        )
        let coordinator = RuntimeServiceCoordinator(
            store: store,
            accessibilityChecker: accessibility,
            eventTapService: service
        )

        coordinator.start()
        drainMainQueue()
        XCTAssertEqual(accessibility.promptCallCount, 1)

        XCTAssertTrue(store.setEnabled(false))
        accessibility.isTrusted = true
        drainMainQueue()

        XCTAssertEqual(backend.startCallCount, 0)
        coordinator.stop()
    }

    func testTrustedEnabledStartupStartsEventTap() {
        let store = makeStore(enabled: true)
        let accessibility = FakeAccessibilityChecker(isTrusted: true)
        let backend = FakeEventTapBackend()
        backend.startResult = true
        let service = EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: FakeEventActionExecutor(),
            backend: backend
        )
        let coordinator = RuntimeServiceCoordinator(
            store: store,
            accessibilityChecker: accessibility,
            eventTapService: service
        )

        coordinator.start()
        drainMainQueue()

        XCTAssertEqual(backend.startCallCount, 1)
        XCTAssertTrue(service.isRunning)
        coordinator.stop()
    }

    private func makeStore(enabled: Bool) -> MappingStore {
        MappingStore(
            configuration: AppConfiguration(
                profiles: [AppProfile.makeDefault()],
                isEnabled: enabled
            ),
            configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
        )
    }

    private func drainMainQueue() {
        let expectation = expectation(description: "Main queue drained")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}

final class DebugMonitorModelTests: XCTestCase {
    func testDebugHistoryIsBoundedAndSubscriptionStops() {
        let backend = FakeEventTapBackend()
        let service = makeEventTapService(backend: backend)
        let model = DebugMonitorModel(eventTapService: service)
        model.start()

        for index in 0...DebugMonitorModel.capacity {
            service.deliverDiagnostic(MouseButtonEvent(
                buttonNumber: Int64(index),
                isDown: true,
                timestamp: Date()
            ))
        }
        XCTAssertEqual(model.events.count, DebugMonitorModel.capacity)

        model.stop()
        service.deliverDiagnostic(MouseButtonEvent(
            buttonNumber: 99,
            isDown: false,
            timestamp: Date()
        ))
        XCTAssertEqual(model.events.count, DebugMonitorModel.capacity)
    }

    private func makeEventTapService(backend: EventTapBackend) -> EventTapService {
        let store = MappingStore(
            configuration: .empty,
            configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
        )
        return EventTapService(
            store: store,
            appMonitor: ActiveAppMonitor(),
            actionExecutor: FakeEventActionExecutor(),
            backend: backend
        )
    }
}

final class PresetActionExecutorTests: XCTestCase {
    func testProductionResolverMapsLogicalCharactersAcrossLayouts() throws {
        let fixtures: [(name: String, inputSourceID: String, zKeyCode: UInt16)] = [
            ("US", "com.apple.keylayout.US", 6),
            ("German QWERTZ", "com.apple.keylayout.German", 16),
            ("French AZERTY", "com.apple.keylayout.French", 13),
        ]
        let requiredCharacters: [Character] = ["n", "f", "m", "[", "]", "c", "v", "z", "q"]

        for fixture in fixtures {
            let resolver = try XCTUnwrap(
                KeyboardLayoutResolver(inputSourceID: fixture.inputSourceID),
                fixture.name
            )
            let zShortcut = try XCTUnwrap(resolver.shortcut(for: "z"), fixture.name)

            XCTAssertEqual(zShortcut.keyCode, fixture.zKeyCode, fixture.name)
            for character in requiredCharacters {
                XCTAssertNotNil(resolver.shortcut(for: character), "\(fixture.name): \(character)")
            }
        }
    }

    func testUndoCombinesLayoutAndCommandModifiers() {
        let poster = RecordingKeyboardEventPoster()
        let keyboardState = KeyboardStateCoordinator(eventPoster: poster)
        let layoutResolver = StaticKeyboardLayoutResolver(shortcuts: [
            "z": KeyboardShortcut(keyCode: 42, modifiers: .init(option: true)),
        ])
        let executor = PresetActionExecutor(
            keyboardState: keyboardState,
            coreDock: CoreDockClient(symbolResolver: MissingSymbolResolver()),
            layoutResolver: layoutResolver
        )

        XCTAssertTrue(executor.perform(.undo))
        XCTAssertTrue(poster.events.contains {
            $0.keyCode == 42 &&
            $0.keyDown &&
            $0.flags.contains(.maskCommand) &&
            $0.flags.contains(.maskAlternate)
        })
    }

    func testDockActionIsUnavailableWhenPrivateSymbolIsMissing() {
        let executor = PresetActionExecutor(
            keyboardState: KeyboardStateCoordinator(eventPoster: RecordingKeyboardEventPoster()),
            coreDock: CoreDockClient(symbolResolver: MissingSymbolResolver()),
            layoutResolver: StaticKeyboardLayoutResolver(shortcuts: [:])
        )

        XCTAssertFalse(executor.isAvailable(.missionControl))
        XCTAssertFalse(executor.perform(.missionControl))
    }
}

final class LaunchAtLoginViewModelTests: XCTestCase {
    func testRequiresApprovalIsPresentedAsEnabled() {
        let service = FakeLaunchAtLoginService(state: .requiresApproval)
        let model = LaunchAtLoginViewModel(service: service)

        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(model.state, .requiresApproval)
    }

    func testRegistrationFailureRefreshesStateAndSurfacesError() {
        let service = FakeLaunchAtLoginService(state: .disabled)
        service.registerError = TestError.expected
        let model = LaunchAtLoginViewModel(service: service)

        model.setEnabled(true)

        XCTAssertEqual(model.state, .disabled)
        XCTAssertNotNil(model.errorMessage)
    }
}

final class ApplicationDiscoveryServiceTests: XCTestCase {
    func testNestedAppsAreDiscoveredAndDeduplicated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try createApp(
            at: root.appendingPathComponent("Vendor/First.app", isDirectory: true),
            bundleIdentifier: "com.example.app",
            name: "First"
        )
        try createApp(
            at: root.appendingPathComponent("Second.app", isDirectory: true),
            bundleIdentifier: "com.example.app",
            name: "Second"
        )

        let service = ApplicationDiscoveryService(
            searchRoots: [root],
            includeRunningApplications: false
        )
        let expectation = expectation(description: "Application discovery")

        service.discover { result in
            guard case .success(let apps) = result else {
                return XCTFail("Expected discovery success")
            }
            XCTAssertEqual(apps.count, 1)
            XCTAssertEqual(apps[0].bundleIdentifier, "com.example.app")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3)
    }

    func testDuplicateRunningBundleIdentifiersDoNotCrash() {
        let first = AppInfo(
            id: "com.example.app",
            name: "First",
            bundleIdentifier: "com.example.app",
            url: URL(fileURLWithPath: "/Applications/First.app"),
            icon: nil
        )
        let second = AppInfo(
            id: "com.example.app",
            name: "Second",
            bundleIdentifier: "com.example.app",
            url: URL(fileURLWithPath: "/Applications/Second.app"),
            icon: nil
        )
        let service = ApplicationDiscoveryService(
            searchRoots: [],
            includeRunningApplications: true,
            runningApplications: [first, second]
        )
        let expectation = expectation(description: "Running application discovery")

        service.discover { result in
            guard case .success(let apps) = result else {
                return XCTFail("Expected discovery success")
            }
            XCTAssertEqual(apps.count, 1)
            XCTAssertEqual(apps[0].bundleIdentifier, "com.example.app")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3)
    }

    func testCancelledDiscoveryDoesNotPublishResults() {
        let service = ApplicationDiscoveryService(
            searchRoots: [],
            includeRunningApplications: false
        )
        let expectation = expectation(description: "No discovery completion")
        expectation.isInverted = true

        let task = service.discover { _ in
            expectation.fulfill()
        }
        task.cancel()

        waitForExpectations(timeout: 0.2)
    }

    private func createApp(at url: URL, bundleIdentifier: String, name: String) throws {
        let contentsURL = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
    }
}

private final class FakeMappingResolver: MappingResolving {
    var mapping: ButtonMapping?
    var availableButtons = Set(MouseButton.allCases)

    init(mapping: ButtonMapping?) {
        self.mapping = mapping
    }

    func resolvedMapping(for button: MouseButton, bundleIdentifier: String?) -> ButtonMapping? {
        mapping
    }

    func isButtonAvailable(_ button: MouseButton) -> Bool {
        availableButtons.contains(button)
    }
}

private final class FakeEventActionExecutor: EventActionExecuting {
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

private struct PostedKeyboardEvent {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}

private final class RecordingKeyboardEventPoster: KeyboardEventPosting {
    var events: [PostedKeyboardEvent] = []

    func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> Bool {
        events.append(PostedKeyboardEvent(keyCode: keyCode, keyDown: keyDown, flags: flags))
        return true
    }
}

private final class FakeEventTapBackend: EventTapBackend {
    var isEnabled = false
    var enableResult = false
    var startResult = false
    var enableCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0

    func start(userInfo: UnsafeMutableRawPointer) -> Bool {
        startCallCount += 1
        isEnabled = startResult
        return startResult
    }

    func enable() -> Bool {
        enableCallCount += 1
        isEnabled = enableResult
        return enableResult
    }

    func stop() {
        stopCallCount += 1
        isEnabled = false
    }
}

private struct MissingSymbolResolver: SymbolResolving {
    func resolve(_ name: String) -> UnsafeMutableRawPointer? {
        nil
    }
}

private struct StaticKeyboardLayoutResolver: KeyboardLayoutResolving {
    let shortcuts: [Character: KeyboardShortcut]

    func shortcut(for character: Character) -> KeyboardShortcut? {
        shortcuts[character]
    }
}

private final class FakeLaunchAtLoginService: LaunchAtLoginManaging {
    var state: LaunchAtLoginState
    var registerError: Error?
    var unregisterError: Error?

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func register() throws {
        if let registerError {
            throw registerError
        }
        state = .enabled
    }

    func unregister() throws {
        if let unregisterError {
            throw unregisterError
        }
        state = .disabled
    }

    func openSystemSettings() {}
}

private final class FakeAccessibilityChecker: AccessibilityChecking {
    @Published var isTrusted: Bool
    var promptCallCount = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    var trustPublisher: AnyPublisher<Bool, Never> {
        $isTrusted.eraseToAnyPublisher()
    }

    func promptIfNeeded() {
        promptCallCount += 1
    }
}

private enum TestError: Error {
    case expected
}
