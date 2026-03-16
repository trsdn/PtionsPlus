import XCTest

final class PtionsPlusUITests: XCTestCase {
    private var configURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        try sampleConfigurationData().write(to: configURL, options: .atomic)
    }

    override func tearDownWithError() throws {
        if let configURL {
            try? FileManager.default.removeItem(at: configURL)
        }
        configURL = nil
    }

    func testLaunchShowsProfilesEditorWithDefaultMapping() {
        let app = makeApp()
        app.launch()

      XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Default"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Button Mappings"].exists)
      XCTAssertTrue(app.staticTexts["Mission Control"].exists)
    }

    func testLaunchUsesSampleMouseModelLabels() {
        let app = makeApp()
        app.launch()

      XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Front Thumb"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Thumb Gesture"].exists)
    }

    func testDefaultProfileShowsFallbackMessaging() {
        let app = makeApp()
        app.launch()

      XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Default defines fallback behavior. Turn on Override Apps for buttons that should ignore app-specific mappings."].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Override Apps"].exists)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchEnvironment["PTIONS_CONFIG_URL"] = configURL.path
        return app
    }

    private func sampleConfigurationData() throws -> Data {
        let json = #"""
        {
          "profiles": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "Default",
              "bundleIdentifier": null,
              "mappings": [
                { "id": "00000000-0000-0000-0000-000000000101", "button": 2 },
                { "id": "00000000-0000-0000-0000-000000000102", "button": 3 },
                { "id": "00000000-0000-0000-0000-000000000103", "button": 4 },
                { "id": "00000000-0000-0000-0000-000000000104", "button": 5, "systemAction": "mission_control" },
                { "id": "00000000-0000-0000-0000-000000000105", "button": 6 }
              ]
            },
            {
              "id": "00000000-0000-0000-0000-000000000002",
              "name": "Mail",
              "bundleIdentifier": "com.apple.mail",
              "mappings": [
                {
                  "id": "00000000-0000-0000-0000-000000000201",
                  "button": 5,
                  "shortcut": {
                    "keyCode": 3,
                    "modifiers": {
                      "command": true
                    }
                  }
                }
              ]
            }
          ],
          "isEnabled": true,
          "launchAtLogin": false,
          "mouseModel": "mx_master_4",
          "globalButtons": []
        }
        """#

        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "PtionsPlusUITests", code: 1)
        }
        return data
    }
}