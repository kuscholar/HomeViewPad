import XCTest
final class HomePadUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication(); app.launchArguments = ["--demo", "--uitesting"]; launchHome()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 10))
    }
    func dismissLocationPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Don")).firstMatch
        if deny.waitForExistence(timeout: 2) { deny.tap() }
    }
    func launchHome() {
        app.launch()
        if !app.launchArguments.contains("--demo") { dismissLocationPrompt() }
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 5))
        app.swipeLeft()
        expectation(for: NSPredicate { _, _ in
            let target: XCUIElement
            if self.app.launchArguments.contains("--fresh") {
                target = self.app.buttons["connectHome"]
            } else if self.app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL") {
                target = self.app.descendants(matching: .any)["climateWidget"]
            } else { target = self.app.buttons["photoWidget"] }
            return !self.app.descendants(matching: .any)["overviewBoard"].exists && target.isHittable
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }
    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func showNavigation() {
        if app.buttons["tab-0"].isHittable { return }
        let point = app.frame.width > app.frame.height ? CGVector(dx: 0.04, dy: 0.5) : CGVector(dx: 0.5, dy: 0.04)
        app.coordinate(withNormalizedOffset: point).tap()
        XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 3))
    }
    func tab(_ index: Int) { showNavigation(); app.buttons["tab-\(index)"].tap() }
    func panel(_ identifier: String) {
        showNavigation(); app.buttons[identifier].tap()
        XCTAssertTrue(app.buttons["dismissPanel"].waitForExistence(timeout: 3))
    }
    func closePanel() { app.buttons["dismissPanel"].tap() }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<8 { if element.isHittable { return }; app.swipeUp() }
    }
    // A reproducible capture journey using only demo accessories and seeded simulator photos.
    // scripts/record_demo.py records between the READY and DONE markers.
    func testReadmeDemoJourney() {
        app.resetAuthorizationStatus(for: .photos); launchHome()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        XCTAssertTrue(app.buttons["album-all"].waitForExistence(timeout: 8)); app.buttons["album-all"].tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10)); closePanel()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        tab(0)
        print("HOMEVIEWPAD_DEMO_READY")
        Thread.sleep(forTimeInterval: 3)
        app.swipeLeft()
        XCTAssertTrue(app.buttons["temperatureUp"].waitForExistence(timeout: 3))
        app.buttons["temperatureUp"].tap()
        XCTAssertEqual(app.staticTexts["temperatureValue"].label, "22.5")
        Thread.sleep(forTimeInterval: 1)
        app.buttons["temperatureDown"].tap()
        app.buttons["accessory-Pendant lights"].tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["accessory-Pendant lights"].tap()
        app.buttons["accessory-Pendant lights"].swipeUp()
        XCTAssertTrue(app.buttons["accessory-Reading lamp"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        app.buttons["accessory-Reading lamp"].swipeDown()
        app.descendants(matching: .any)["climateWidget"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_PHOTOS")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        let wall = app.descendants(matching: .any)["photoWall"]
        shot("README photo wall 1")
        // Capture two real 30-second album transitions without changing app timing.
        for index in 2...3 {
            let previousPhoto = wall.value as? String
            expectation(for: NSPredicate { _, _ in wall.value as? String != previousPhoto }, evaluatedWith: nil)
            waitForExpectations(timeout: 36)
            print("HOMEVIEWPAD_DEMO_PHOTO_\(index)")
            shot("README photo wall \(index)")
        }
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_RETURN")
        app.swipeRight(); app.swipeRight(); app.swipeRight()
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 3))
        showNavigation(); Thread.sleep(forTimeInterval: 2)
        app.buttons["hideNavigation"].tap()
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_DONE")
        shot("README demo dashboard")
    }
    func testDashboardRepeatedControlsAndSceneCancellation() {
        shot("Portrait dashboard")
        let lamp = app.buttons["accessory-Pendant lights"]
        lamp.tap(); XCTAssertTrue(lamp.label.contains("Off")); lamp.tap(); XCTAssertTrue(lamp.label.contains("On"))
        panel("allControls")
        reveal(app.buttons["scene-Good night"])
        app.buttons["scene-Good night"].tap(); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.label.contains("On"))
        app.buttons["scene-Good night"].tap(); app.buttons["Run scene"].tap()
        XCTAssertTrue(app.staticTexts["sceneNotice"].waitForExistence(timeout: 3))
        closePanel()
        XCTAssertTrue(lamp.label.contains("Off"))
    }
    func testImmersiveLandscapeGeometryAndHiddenNavigation() {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        let hero = app.descendants(matching: .any)["climateWidget"]
        let clock = app.descendants(matching: .any)["clockWidget"]
        let photo = app.buttons["photoWidget"]
        let bottom = app.buttons["accessory-Pendant lights"]
        XCTAssertEqual(hero.frame.width, hero.frame.height, accuracy: 2)
        XCTAssertEqual(hero.frame.minY, clock.frame.minY, accuracy: 2)
        XCTAssertEqual(clock.frame.minX, photo.frame.minX, accuracy: 2)
        XCTAssertEqual(hero.frame.maxY, photo.frame.maxY, accuracy: 2)
        XCTAssertLessThan(hero.frame.maxX, clock.frame.minX)
        let scene = app.buttons["scene-Good morning"], fan = app.buttons["accessory-Ceiling fan"]
        XCTAssertEqual(scene.frame.minX, hero.frame.minX, accuracy: 2)
        XCTAssertEqual(scene.frame.minY, fan.frame.minY, accuracy: 2)
        XCTAssertEqual(fan.frame.minY, bottom.frame.minY, accuracy: 2)
        XCTAssertEqual(bottom.frame.minX, photo.frame.minX, accuracy: 2)
        XCTAssertEqual(clock.frame.width, clock.frame.height, accuracy: 2)
        XCTAssertEqual(photo.frame.width, photo.frame.height, accuracy: 2)
        XCTAssertEqual(bottom.frame.width, bottom.frame.height, accuracy: 2)
        XCTAssertGreaterThan(bottom.frame.maxY - hero.frame.minY, app.frame.height * 0.96)
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertFalse(app.navigationBars.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["HomeViewPad"].exists)
        shot("Landscape dashboard")
        showNavigation()
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, bottom.frame.maxX)
        shot("Right navigation")
        app.buttons["hideNavigation"].tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
        // Background taps toggle the rail without toggling an accessory.
        showNavigation(); app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.label.contains("On"))
    }
    func testPortraitDockMovesToRightOnRotation() {
        XCTAssertFalse(app.descendants(matching: .any)["bottomNavigation"].exists)
        showNavigation()
        XCTAssertTrue(app.descendants(matching: .any)["bottomNavigation"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["sideNavigation"].exists)
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minY, app.frame.height * 0.8)
        XCTAssertEqual(app.buttons["tab-0"].frame.midY, app.buttons["tab-4"].frame.midY, accuracy: 2)
        shot("Portrait bottom navigation")
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["bottomNavigation"].exists)
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, app.frame.width * 0.8)
        app.buttons["hideNavigation"].tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
    }
    func testBlackOverviewLayoutAndLiveWeatherDisclosure() {
        tab(0)
        let date = app.descendants(matching: .any)["overviewDate"]
        let clock = app.descendants(matching: .any)["overviewClock"]
        let album = app.buttons["overviewAlbum"]
        let weather = app.descendants(matching: .any)["overviewWeather"]
        func assertGrid() {
            // SwiftUI can expose intermediate accessibility frames during a page transition.
            expectation(for: NSPredicate { _, _ in
                [date, clock, album, weather].allSatisfy { widget in
                    guard widget.exists else { return false }
                    let frame = widget.frame
                    return frame.width > 0 && abs(frame.width - frame.height) < 2
                }
            }, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
            for widget in [date, clock, album, weather] {
                XCTAssertTrue(widget.exists)
                let frame = widget.frame
                XCTAssertEqual(frame.width, frame.height, accuracy: 2)
            }
            XCTAssertEqual(date.frame.minY, clock.frame.minY, accuracy: 2)
            XCTAssertEqual(date.frame.minX, album.frame.minX, accuracy: 2)
            XCTAssertEqual(clock.frame.minX, weather.frame.minX, accuracy: 2)
            XCTAssertEqual(album.frame.minY, weather.frame.minY, accuracy: 2)
            XCTAssertLessThan(date.frame.maxY, album.frame.minY)
            XCTAssertFalse(app.buttons["tab-0"].exists)
            XCTAssertFalse(app.navigationBars.firstMatch.exists)
        }
        assertGrid(); XCTAssertTrue(weather.label.contains("54°"))
        XCTAssertTrue(app.staticTexts["demoBadge"].exists)
        shot("Black overview portrait")
        album.tap(); XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 3)); closePanel()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        assertGrid(); shot("Black overview landscape")
        showNavigation(); XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
        app.buttons["hideNavigation"].tap()
        app.swipeRight(); XCTAssertTrue(album.exists)
        app.swipeLeft(); XCTAssertTrue(app.buttons["photoWidget"].waitForExistence(timeout: 3))
        app.swipeLeft(); XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        tab(0); assertGrid()
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: weather); waitForExpectations(timeout: 5)
        weather.tap()
        XCTAssertTrue(app.staticTexts["weatherDemoNotice"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["weatherCitySearch"].exists)
        closePanel()
        app.terminate(); app.launch()
        XCTAssertTrue(album.waitForExistence(timeout: 5)) // Overview is the launch page.
        XCTAssertFalse(app.buttons["photoWidget"].exists)
    }
    func testHorizontalPagingAndIndependentWidgetSwipes() {
        let photo = app.buttons["photoWidget"]
        // This journey checks the empty photo wall; don't inherit a prior run's album.
        photo.tap()
        let clear = app.buttons["clearPhotos"]; reveal(clear); clear.tap(); closePanel()
        XCTAssertFalse(app.descendants(matching: .any)["widgetPosition-2"].exists)
        photo.swipeUp()
        XCTAssertTrue(app.buttons["cameraWidget"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["climateWidget"].exists)
        XCTAssertFalse(app.buttons["dismissPanel"].exists)
        app.buttons["cameraWidget"].swipeDown()
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dismissPanel"].exists)
        let lamp = app.buttons["accessory-Pendant lights"]
        lamp.swipeUp()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: lamp); waitForExpectations(timeout: 3)
        XCTAssertEqual(app.buttons.matching(identifier: "accessory-Reading lamp").count, 1)
        XCTAssertTrue(app.buttons["accessory-Ceiling fan"].exists)
        app.buttons["accessory-Reading lamp"].swipeDown()
        XCTAssertTrue(lamp.waitForExistence(timeout: 3)); XCTAssertTrue(lamp.label.contains("On"))
        app.descendants(matching: .any)["climateWidget"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        shot("Clock page")
        app.swipeLeft(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["chooseWallAlbum"].exists)
        app.swipeLeft(); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Start timer"].exists)
        app.swipeRight(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        tab(1); XCTAssertTrue(photo.exists); XCTAssertTrue(lamp.label.contains("On"))
        XCTAssertFalse(app.buttons["tab-0"].exists)
    }
    func testThermostatArrowsAndTransientIndicators() {
        let value = app.staticTexts["temperatureValue"]
        let up = app.buttons["temperatureUp"], down = app.buttons["temperatureDown"]
        XCTAssertEqual(value.label, "22.0")
        up.tap(); XCTAssertEqual(value.label, "22.5")
        down.tap(); XCTAssertEqual(value.label, "22.0")
        let hero = app.descendants(matching: .any)["climateWidget"]
        XCTAssertTrue(hero.frame.contains(value.frame))
        XCTAssertTrue(hero.frame.contains(up.frame)); XCTAssertTrue(hero.frame.contains(down.frame))
        shot("Thermostat complete digits and arrows")
        let position = app.descendants(matching: .any)["widgetPosition-0"]
        XCTAssertFalse(position.exists)
        hero.swipeUp()
        XCTAssertEqual(value.label, "21.5")
        XCTAssertFalse(up.isEnabled); XCTAssertFalse(down.isEnabled)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: position)
        waitForExpectations(timeout: 4)
        XCTAssertTrue(app.buttons["photoWidget"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["clockWidget"].exists)
        hero.swipeDown(); XCTAssertTrue(up.isEnabled)
        XCTAssertEqual(value.label, "22.0")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        tab(4); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        showNavigation(); XCTAssertFalse(app.buttons["tab-5"].exists)
        XCTAssertFalse(app.buttons["Start timer"].exists)
    }
    func testLandscapeCameraAndAgenda() {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        panel("agendaCard"); XCTAssertTrue(app.staticTexts["17:30 · Water the plants"].exists); closePanel()
        panel("cameraCard"); XCTAssertTrue(app.staticTexts["Demo camera"].waitForExistence(timeout: 5)); shot("Camera placeholder"); closePanel()
        tab(2); shot("Clock landscape")
    }
    func testFailureStatesAndReturnToRealOnboarding() {
        for state in ["denied", "empty", "offline", "loading"] {
            tab(4); reveal(app.buttons["Simulate \(state)"]); app.buttons["Simulate \(state)"].tap()
            XCTAssertTrue(app.staticTexts["homeStateTitle"].waitForExistence(timeout: 3)); XCTAssertTrue(app.staticTexts["demoBadge"].exists); shot("State \(state)")
        }
        tab(4); app.buttons["Disconnect home"].tap()
        XCTAssertTrue(app.buttons["connectHome"].exists); XCTAssertFalse(app.staticTexts["demoBadge"].exists); shot("Real onboarding")
        app.buttons["exploreDemo"].tap(); XCTAssertTrue(app.staticTexts["demoBadge"].exists)
    }
    func testStandbyEnableRequestsMicrophoneAndDeniedAccessBlocksDimming() {
        app.terminate(); app.resetAuthorizationStatus(for: .microphone)
        app.launchArguments = ["--fresh", "--uitesting", "-standbyWakeMode", "sound", "-standbyEnabled", "NO"]
        app.launch(); dismissLocationPrompt()
        tab(4)
        let settings = app.buttons["standbySettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        let toggle = app.switches["standbyEnabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() } else { toggle.tap() }
        let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Don")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5)); deny.tap()
        let status = app.staticTexts["standbyStatus"]
        reveal(status)
        XCTAssertTrue(status.label.contains("Microphone access is required"))
        reveal(app.buttons["standbyNow"]); XCTAssertFalse(app.buttons["standbyNow"].isEnabled)
        shot("Standby missing microphone permission")
        closePanel(); tab(0)
        XCTAssertTrue(app.buttons["standbySetupIssue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["standbySurface"].exists)
        app.terminate(); app.resetAuthorizationStatus(for: .microphone)
    }
    func testForegroundStandbyDemoWakeAndBackgroundRecovery() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "-standbyWakeMode", "soundAndDepth"]
        launchHome()
        func openStandby() {
            tab(4)
            let settings = app.buttons["standbySettings"]
            expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: settings)
            waitForExpectations(timeout: 5)
            settings.tap()
            XCTAssertTrue(app.switches["standbyEnabled"].waitForExistence(timeout: 5))
        }
        func start() {
            reveal(app.buttons["standbyNow"]); app.buttons["standbyNow"].tap()
            XCTAssertTrue(app.buttons["standbyDemoSound"].waitForExistence(timeout: 5))
        }
        openStandby()
        XCTAssertFalse(app.buttons["standbyPermissions"].exists)
        let toggle = app.switches["standbyEnabled"]
        if toggle.value as? String == "0" {
            if toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() } else { toggle.tap() }
        }
        XCTAssertEqual(toggle.value as? String, "1")
        shot("Standby settings demo")
        reveal(app.staticTexts["standbyDemoNotice"])
        XCTAssertTrue(app.staticTexts["standbyDemoNotice"].exists)
        start(); shot("Standby demo dimmed")
        app.buttons["standbyDemoSound"].tap()
        XCTAssertTrue(app.buttons["standbyDemoNoFace"].waitForExistence(timeout: 2)); app.buttons["standbyDemoNoFace"].tap()
        XCTAssertTrue(app.buttons["standbyDemoWake"].exists)
        app.buttons["standbyDemoWake"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 5))
        openStandby(); start(); app.buttons["standbyDemoSound"].tap()
        XCTAssertTrue(app.buttons["standbyDemoFace"].waitForExistence(timeout: 2)); app.buttons["standbyDemoFace"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 5))
        openStandby(); start(); XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["standbyDemoWake"].exists)
        openStandby(); if toggle.value as? String == "1" {
            if toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() } else { toggle.tap() }
        }
        closePanel()
    }
    func testDebugWeatherProviderSwitchAndPersistence() {
        app.terminate()
        app.launchArguments = ["--fresh", "--uitesting", "-debugWeatherProvider", "openMeteo", "-weatherFollowsLocation", "NO"]
        app.launch()
        let weather = app.buttons["overviewWeather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        app.buttons["removeWeatherCity"].tap()
        XCTAssertTrue(app.staticTexts["weatherLiveReading"].waitForExistence(timeout: 30))
        closePanel()
        XCTAssertTrue(app.links["openMeteoAttribution"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.links["appleWeatherAttribution"].exists)
        shot("Debug Open-Meteo live overview")
        weather.tap()
        let form = app.collectionViews.firstMatch
        let picker = app.segmentedControls["weatherProviderPicker"]
        for _ in 0..<6 { if picker.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(picker.buttons["Open-Meteo"].isSelected)
        shot("Debug weather provider options")
        picker.buttons["WeatherKit"].tap()
        XCTAssertTrue(picker.buttons["WeatherKit"].isSelected)
        XCTAssertFalse(form.descendants(matching: .any)["openMeteoAttribution"].exists)
        for _ in 0..<5 { if app.staticTexts["weatherSelectedCity"].isHittable { break }; form.swipeDown() }
        assertWeatherServiceResult()
        closePanel()
        XCTAssertFalse(app.links["openMeteoAttribution"].exists)
        app.terminate()
        // Remove launch-domain overrides: the user's persisted choice must survive relaunch.
        app.launchArguments = ["--fresh", "--uitesting"]
        app.launch(); XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        for _ in 0..<6 { if picker.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(picker.buttons["WeatherKit"].isSelected)
        picker.buttons["Open-Meteo"].tap()
        XCTAssertTrue(picker.buttons["Open-Meteo"].isSelected)
        for _ in 0..<5 { if app.staticTexts["weatherSelectedCity"].isHittable { break }; form.swipeDown() }
        XCTAssertTrue(app.staticTexts["weatherLiveReading"].waitForExistence(timeout: 30))
        closePanel()
        XCTAssertTrue(app.links["openMeteoAttribution"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("Debug Open-Meteo live landscape")
    }
    // Unsigned simulators exercise either real data or the explicit service-error state.
    // A passing test does not certify WeatherKit authorization or network availability.
    func assertWeatherServiceResult() {
        let reading = app.staticTexts["weatherLiveReading"]
        let error = app.staticTexts["weatherUnavailable"]
        expectation(for: NSPredicate { _, _ in reading.exists || error.exists }, evaluatedWith: nil)
        waitForExpectations(timeout: 40)
        if reading.exists { XCTAssertTrue(app.descendants(matching: .any)["appleWeatherAttribution"].exists) }
        else { XCTAssertTrue(error.exists); XCTAssertFalse(app.staticTexts["weatherPreviewNotice"].exists) }
    }
    func testWeatherAttributionLayoutWithLabeledFixture() {
        app.terminate()
        app.launchArguments = ["--fresh", "--uitesting", "--weather-preview", "-weatherFollowsLocation", "NO", "-weatherFahrenheit", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["weatherPreviewBadge"].waitForExistence(timeout: 5))
        // SwiftUI exposes Link as a button on iPadOS 26 and as a link on iPadOS 27.
        let attribution = app.descendants(matching: .any)["appleWeatherAttribution"]
        XCTAssertTrue(attribution.waitForExistence(timeout: 5))
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(attribution.isHittable)
            XCTAssertTrue(app.buttons["overviewWeather"].label.contains("54°"))
            shot(orientation == .portrait ? "WeatherKit fixture portrait" : "WeatherKit fixture landscape")
        }
        app.buttons["overviewWeather"].tap()
        XCTAssertTrue(app.staticTexts["weatherPreviewNotice"].waitForExistence(timeout: 5))
        let form = app.collectionViews.firstMatch
        let panelAttribution = form.descendants(matching: .any)["appleWeatherAttribution"]
        for _ in 0..<6 {
            if panelAttribution.isHittable { break }
            form.swipeUp()
        }
        XCTAssertTrue(panelAttribution.isHittable, form.debugDescription)
        shot("WeatherKit fixture attribution panel")
    }
    func testWeatherCitySearchPersistenceAndServiceState() {
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting", "-debugWeatherProvider", "weatherKit", "-weatherFollowsLocation", "YES"]; app.launch()
        dismissLocationPrompt()
        let weather = app.buttons["overviewWeather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        XCTAssertTrue(app.textFields["weatherCitySearch"].waitForExistence(timeout: 5))
        app.buttons["removeWeatherCity"].tap() // Explicitly choose the Philadelphia fallback.
        XCTAssertEqual(app.staticTexts["weatherSelectedCity"].label, "Philadelphia")
        assertWeatherServiceResult()
        XCTAssertFalse(app.staticTexts["demoBadge"].exists)
        shot("WeatherKit Philadelphia service state")
        let search = app.textFields["weatherCitySearch"]
        search.tap(); search.typeText("New York\n")
        XCTAssertEqual(search.value as? String, "New York")
        app.collectionViews.firstMatch.swipeUp()
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "weatherCity-", "New York")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        let form = app.collectionViews.firstMatch
        // Keep the row clear of the translucent navigation bar before tapping.
        for _ in 0..<6 {
            let visible = form.frame.insetBy(dx: 10, dy: 100)
            let center = CGPoint(x: result.frame.midX, y: result.frame.midY)
            if visible.contains(center), result.isHittable { break }
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: 0, dy: center.y < visible.minY ? 160 : -160))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(form.frame.insetBy(dx: 10, dy: 100).contains(CGPoint(x: result.frame.midX, y: result.frame.midY)))
        shot("Weather city search"); result.tap()
        // Search results scroll the form; the selected city's reading is above them.
        for _ in 0..<3 {
            if app.staticTexts["weatherSelectedCity"].isHittable { break }
            app.collectionViews.firstMatch.swipeDown()
        }
        assertWeatherServiceResult()
        XCTAssertTrue(app.staticTexts["weatherSelectedCity"].label.contains("New York"), app.staticTexts["weatherSelectedCity"].label)
        closePanel(); shot("WeatherKit overview service state")
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting", "-debugWeatherProvider", "weatherKit"]; app.launch()
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        XCTAssertTrue(app.staticTexts["weatherSelectedCity"].label.contains("New York"))
        app.buttons["removeWeatherCity"].tap() // Leave the simulator on the requested default city.
        closePanel()
    }
    func testLocationPermissionUsesDetectedCity() {
        app.terminate(); app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["--fresh", "--uitesting", "-debugWeatherProvider", "weatherKit", "-weatherFollowsLocation", "YES"]; app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        XCTAssertTrue(allow.waitForExistence(timeout: 8)); allow.tap()
        let weather = app.buttons["overviewWeather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        let status = app.staticTexts["weatherLocationStatus"]
        expectation(for: NSPredicate { _, _ in status.label.contains("Using your current city") }, evaluatedWith: nil)
        waitForExpectations(timeout: 40)
        assertWeatherServiceResult()
        XCTAssertFalse(app.staticTexts["demoBadge"].exists)
        shot("Apple location and WeatherKit service state")
        app.buttons["removeWeatherCity"].tap(); closePanel()
    }
    func testRealConnectionGracefulWithoutDevices() {
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting"]; launchHome()
        XCTAssertTrue(app.buttons["connectHome"].waitForExistence(timeout: 5)); app.buttons["connectHome"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Don’t Allow"].waitForExistence(timeout: 3) { springboard.buttons["Don’t Allow"].tap() }
        else if springboard.buttons["Don't Allow"].exists { springboard.buttons["Don't Allow"].tap() }
        expectation(for: NSPredicate { _, _ in
            ["Home access is off", "Your home starts here", "Home is taking a moment"].contains(self.app.staticTexts["homeStateTitle"].label)
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 25); XCTAssertFalse(app.staticTexts["demoBadge"].exists); shot("Real connection without devices")
    }
    func testSystemPickerDismissal() {
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 3))
        app.buttons["singlePhotoPicker"].tap()
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.swipeDown() }
        closePanel()
        panel("musicCard"); app.buttons["Choose audio file"].tap()
        // The remote Files service can take longer to load on a fresh CI simulator.
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 20)); shot("Audio file picker"); app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Choose audio file"].waitForExistence(timeout: 5))
        closePanel(); tab(1); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testPhotoLibraryDenialKeepsSinglePhotoAvailable() {
        app.resetAuthorizationStatus(for: .photos)
        launchHome() // Resetting an existing Photos grant terminates the app.
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Allow")).matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Don")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5)); deny.tap()
        XCTAssertTrue(app.staticTexts["photosDenied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["singlePhotoPicker"].exists); shot("Photo permission denied")
        closePanel(); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testPhotoLibraryAlbumDisplayRotationRestoreAndRemoval() {
        app.launchArguments += ["-photoSlideshow", "YES"]
        app.resetAuthorizationStatus(for: .photos)
        launchHome()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        let album = app.buttons["album-all"]
        XCTAssertTrue(album.waitForExistence(timeout: 8)); album.tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        shot("Photo album selection")
        let position = app.staticTexts["photoPosition"]
        reveal(position); let initial = position.label
        XCTAssertTrue(app.buttons["nextPhoto"].isEnabled); app.buttons["nextPhoto"].tap()
        expectation(for: NSPredicate { _, _ in position.label != initial }, evaluatedWith: nil); waitForExpectations(timeout: 5)
        closePanel(); shot("Dashboard with library photo")
        tab(0)
        let overviewAlbum = app.buttons["overviewAlbum"]
        XCTAssertFalse((overviewAlbum.value as? String ?? "").contains("No photo"))
        let overviewPosition = overviewAlbum.value as? String
        expectation(for: NSPredicate { _, _ in overviewAlbum.value as? String != overviewPosition }, evaluatedWith: nil)
        waitForExpectations(timeout: 36)
        shot("Black overview with album")
        overviewAlbum.tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 5)); closePanel()
        tab(3)
        let wall = app.descendants(matching: .any)["photoWall"]
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseWallAlbum"].exists)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall portrait")
        let firstPhoto = wall.value as? String
        expectation(for: NSPredicate { _, _ in wall.value as? String != firstPhoto }, evaluatedWith: nil)
        waitForExpectations(timeout: 36) // Actual 30-second slideshow, no shortened test timer.
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall landscape")
        showNavigation(); XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
        app.buttons["hideNavigation"].tap()
        app.swipeLeft(); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        app.swipeRight(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        app.terminate(); launchHome()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        // Revoking permission must not restore the cached album image on relaunch.
        app.resetAuthorizationStatus(for: .photos); launchHome()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["photoPreview"].exists)
        XCTAssertTrue(app.staticTexts["photoMessage"].exists)
        let clear = app.buttons["clearPhotos"]; reveal(clear); clear.tap()
        XCTAssertFalse(app.images["photoPreview"].exists); XCTAssertFalse(app.staticTexts["photoPosition"].exists)
        closePanel(); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testRoomFilteringCanBeRepeated() {
        panel("allControls")
        app.buttons["room-Kitchen"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.exists); XCTAssertFalse(app.buttons.matching(identifier: "accessory-Reading lamp").firstMatch.exists)
        app.buttons["room-All rooms"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Reading lamp").firstMatch.exists); closePanel()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.exists)
    }
    func testLargeTextLayout() {
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]; launchHome()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 5)); shot("Accessibility large text")
        reveal(app.buttons["photoWidget"]); XCTAssertTrue(app.buttons["photoWidget"].isHittable)
        tab(4); XCTAssertTrue(app.buttons["Disconnect home"].exists)
    }
    func testGlassThemePersistsAfterNavigation() {
        tab(4)
        let teal = app.switches["tealWallpaper"]
        if teal.switches.firstMatch.exists { teal.switches.firstMatch.tap() } else { teal.tap() }
        XCTAssertEqual(teal.value as? String, "1")
        tab(1); shot("Teal dashboard")
        tab(4); XCTAssertEqual(app.switches["tealWallpaper"].value as? String, "1")
        tab(1); XCTAssertTrue(app.descendants(matching: .any)["climateWidget"].exists)
    }
}
