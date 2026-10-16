import XCTest
@testable import HomePad

@MainActor private final class StandbySensorStub: StandbySensing {
    var hasTrueDepth = true, microphoneAllowed = true, cameraAllowed = true
    var permissionCalls = 0, listens = 0, checks = 0, stops = 0
    var grantOnRequest = false, failToStart = false
    var level: ((Float) -> Void)?, failure: ((String) -> Void)?
    var results: [(Bool) -> Void] = []
    func requestPermissions(depth: Bool) async {
        permissionCalls += 1
        if grantOnRequest { microphoneAllowed = true; if depth { cameraAllowed = true } }
    }
    func listen(level: @escaping (Float) -> Void, failure: @escaping (String) -> Void) throws {
        listens += 1; self.level = level; self.failure = failure
        if failToStart { throw NSError(domain: "StandbyTests", code: 1) }
    }
    func checkFace(completion: @escaping (Bool) -> Void) { checks += 1; results.append(completion) }
    func stop() { stops += 1 }
}

@MainActor private final class StandbyFixture {
    var time = Date(timeIntervalSince1970: 1000)
    var brightness: CGFloat = 0.63
    let name = "StandbyTests.\(UUID())"
    let defaults: UserDefaults
    let sensors = StandbySensorStub()
    var store: StandbyStore!
    init(demo: Bool = false, mode: StandbyWakeMode? = .soundAndDepth) {
        defaults = UserDefaults(suiteName: name)!
        if let mode { defaults.set(mode.rawValue, forKey: "standbyWakeMode") }
        store = StandbyStore(defaults: defaults, sensors: sensors, now: { [unowned self] in self.time },
                             readBrightness: { [unowned self] in self.brightness }, writeBrightness: { [unowned self] in self.brightness = $0 })
        store.environment(active: true, available: true, demo: demo)
    }
    func cleanup() { store.enabled = false; defaults.removePersistentDomain(forName: name) }
    func sleep() { store.enabled = true; store.dim() }
}

final class StandbyTests: XCTestCase {
    func testSoundGateRequiresCalibrationAndQuietRearm() {
        var gate = StandbySoundGate()
        for _ in 0..<12 { XCTAssertFalse(gate.consume(-60)) }
        XCTAssertFalse(gate.consume(-50)); XCTAssertTrue(gate.consume(-50))
        for _ in 0..<10 { XCTAssertFalse(gate.consume(-50)) }
        XCTAssertFalse(gate.consume(-60)); XCTAssertFalse(gate.consume(-50)); XCTAssertTrue(gate.consume(-50))
        XCTAssertFalse(gate.consume(.nan)); XCTAssertFalse(gate.consume(.infinity))
        var loudRoom = StandbySoundGate()
        for _ in 0..<50 { XCTAssertFalse(loudRoom.consume(-20)) }
    }
    func testBriefSoundAndQuieterSpeechAreNotDiscardedByOldAbsoluteLimit() {
        var transient = StandbySoundGate()
        for _ in 0..<12 { XCTAssertFalse(transient.consume(-65)) }
        // One buffer, still below the old -38 dBFS cutoff.
        XCTAssertTrue(transient.consume(-45))
        var speech = StandbySoundGate()
        for _ in 0..<12 { XCTAssertFalse(speech.consume(-65)) }
        XCTAssertFalse(speech.consume(-51)); XCTAssertTrue(speech.consume(-50))
    }
    func testSensitivityAndSteadyBackgroundNoise() {
        for sensitivity in StandbySoundSensitivity.allCases {
            var gate = StandbySoundGate(sensitivity: sensitivity)
            for _ in 0..<200 { XCTAssertFalse(gate.consume(-35)) }
        }
        var low = StandbySoundGate(sensitivity: .low), high = StandbySoundGate(sensitivity: .high)
        for _ in 0..<12 { _ = low.consume(-70); _ = high.consume(-70) }
        XCTAssertFalse(low.consume(-60)); XCTAssertFalse(low.consume(-60))
        XCTAssertFalse(high.consume(-60)); XCTAssertTrue(high.consume(-60))
        // Sounds that used to trigger Low now stay below its gate, both in a
        // quiet room and where the relative room-noise margin dominates.
        for (ambient, softer, deliberate): (Float, Float, Float) in [(-70, -42, -38), (-40, -26, -21)] {
            var lessSensitive = StandbySoundGate(sensitivity: .low)
            for _ in 0..<12 { XCTAssertFalse(lessSensitive.consume(ambient)) }
            XCTAssertFalse(lessSensitive.consume(softer)); XCTAssertFalse(lessSensitive.consume(softer))
            XCTAssertFalse(lessSensitive.consume(deliberate)); XCTAssertTrue(lessSensitive.consume(deliberate))
        }
    }
    @MainActor func testUnsetModeDefaultsToSoundAndPreservesExplicitDepthChoice() {
        let implicit = StandbyFixture(mode: nil); defer { implicit.cleanup() }
        XCTAssertEqual(implicit.store.mode, .sound)
        implicit.sensors.cameraAllowed = false; implicit.sensors.hasTrueDepth = false
        implicit.sleep()
        for _ in 0..<12 { implicit.sensors.level?(-65) }
        implicit.sensors.level?(-51); implicit.sensors.level?(-50)
        XCTAssertFalse(implicit.store.dimmed); XCTAssertEqual(implicit.brightness, 0.63)
        XCTAssertEqual(implicit.sensors.checks, 0)
        XCTAssertTrue(implicit.store.lastDetection.contains("Sound detected"))
        let explicit = StandbyFixture(mode: .soundAndDepth); defer { explicit.cleanup() }
        XCTAssertEqual(explicit.store.mode, .soundAndDepth)
    }
    @MainActor func testDepthMissIsReportedWithoutSilentlyBypassingChosenMode() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.store.showSoundLevels = true; f.sleep()
        for _ in 0..<12 { f.sensors.level?(-65) }
        f.sensors.level?(-45)
        XCTAssertEqual(f.sensors.checks, 1); XCTAssertEqual(f.store.soundLevel, -45)
        f.sensors.results[0](false)
        XCTAssertTrue(f.store.dimmed)
        XCTAssertTrue(f.store.lastDetection.contains("no nearby face confirmed"))
        f.sensors.level?(-65) // Starting the mic again must not erase the check result.
        XCTAssertTrue(f.store.lastDetection.contains("no nearby face confirmed"))
        f.store.activity(); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testDisabledHasNoSensorsAndIdleNeedsElapsedTime() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.time += 600; f.store.tick(); XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.sensors.listens, 0)
        f.store.enabled = true; f.time += 59; f.store.tick(); XCTAssertFalse(f.store.dimmed)
        f.store.activity(); f.time += 59; f.store.tick(); XCTAssertFalse(f.store.dimmed)
        f.time += 1; f.store.tick(); XCTAssertTrue(f.store.dimmed); XCTAssertEqual(f.sensors.listens, 1)
        XCTAssertEqual(f.sensors.checks, 0); XCTAssertEqual(f.brightness, 0)
    }
    @MainActor func testSoundOnlyWakesWithoutCameraAndRestoresBrightness() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.store.mode = .sound; f.sleep(); f.store.soundDetected()
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.sensors.checks, 0); XCTAssertEqual(f.brightness, 0.63)
        f.brightness = 0.42; f.store.dim(); f.store.activity(); XCTAssertEqual(f.brightness, 0.42)
    }
    @MainActor func testTrueDepthOnlyStartsAfterSoundAndFailureIsRateLimited() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sleep(); XCTAssertEqual(f.sensors.checks, 0)
        f.store.soundDetected(); XCTAssertTrue(f.store.checking); XCTAssertEqual(f.sensors.checks, 1)
        f.sensors.results[0](false); XCTAssertTrue(f.store.dimmed); XCTAssertFalse(f.store.checking)
        XCTAssertEqual(f.sensors.listens, 2)
        f.store.soundDetected(); XCTAssertEqual(f.sensors.checks, 1)
        f.time += 15; f.store.soundDetected(); XCTAssertEqual(f.sensors.checks, 2)
        f.sensors.results[0](true); XCTAssertTrue(f.store.checking); XCTAssertTrue(f.store.dimmed)
        f.sensors.results[1](true); XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testTimeoutStopsCameraAndReturnsToListening() async throws {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sleep(); f.store.soundDetected(); let stops = f.sensors.stops
        try await Task.sleep(for: .milliseconds(3200))
        XCTAssertFalse(f.store.checking); XCTAssertTrue(f.store.dimmed)
        XCTAssertGreaterThan(f.sensors.stops, stops); XCTAssertEqual(f.sensors.listens, 2)
        f.sensors.results[0](true); XCTAssertTrue(f.store.dimmed) // Expired result cannot wake.
    }
    @MainActor func testBackgroundAndDisableCancelLateCallbacks() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sleep(); f.store.soundDetected()
        f.store.environment(active: false, available: false, demo: false)
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        f.sensors.results[0](true); XCTAssertFalse(f.store.checking)
        f.store.environment(active: true, available: true, demo: false); f.store.dim(); f.store.soundDetected()
        f.store.enabled = false; f.sensors.results[1](true)
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testPanelOrPlaybackSuspendsAndDoesNotReuseOldIdleTime() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sleep(); f.store.environment(active: true, available: false, demo: false)
        f.time += 600; f.store.tick(); XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        f.store.environment(active: true, available: true, demo: false); f.store.tick(); XCTAssertFalse(f.store.dimmed)
    }
    @MainActor func testDeniedOrUnsupportedDepthNeverUsesRegularCamera() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sensors.hasTrueDepth = false; f.sleep()
        XCTAssertFalse(f.store.permitted); XCTAssertEqual(f.sensors.listens, 0); XCTAssertEqual(f.sensors.checks, 0)
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        f.store.mode = .sound; f.store.dim(); XCTAssertEqual(f.sensors.listens, 1)
        f.store.wake(); f.sensors.microphoneAllowed = false; f.store.dim()
        XCTAssertFalse(f.store.dimmed); XCTAssertNotNil(f.store.setupIssue)
        XCTAssertEqual(f.sensors.listens, 1); f.store.activity(); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testDemoNeverRequestsOrStartsHardwareAndModeSwitchCancels() async {
        let f = StandbyFixture(demo: true); defer { f.cleanup() }
        await f.store.requestPermissions(); f.sleep(); f.store.soundDetected(); f.store.simulateFace(true)
        XCTAssertEqual(f.sensors.permissionCalls, 0); XCTAssertEqual(f.sensors.listens, 0); XCTAssertEqual(f.sensors.checks, 0)
        XCTAssertFalse(f.store.dimmed)
        f.store.environment(active: true, available: true, demo: false); f.store.dim(); f.store.soundDetected()
        f.store.environment(active: true, available: true, demo: true); f.sensors.results[0](true)
        XCTAssertFalse(f.store.dimmed)
    }
    @MainActor func testAudioFailureRestoresBrightnessAndBlocksSilentRetry() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sleep(); let callback = f.sensors.level
        f.sensors.failure?("Interrupted.")
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        XCTAssertTrue(f.store.message.contains("Interrupted"))
        f.time += 600; f.store.tick(); XCTAssertFalse(f.store.dimmed)
        for _ in 0..<20 { callback?(-60) }; callback?(-10); callback?(-10)
        XCTAssertEqual(f.sensors.checks, 0)
        f.store.activity(); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testMissingPermissionsPreventIdleDimmingUntilGranted() async {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sensors.microphoneAllowed = false; f.sensors.cameraAllowed = false
        f.store.enabled = true; f.time += 60; f.store.tick()
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        XCTAssertEqual(f.sensors.listens, 0); XCTAssertTrue(f.store.message.contains("Microphone"))
        f.sensors.grantOnRequest = true
        await f.store.requestPermissions()
        XCTAssertEqual(f.sensors.permissionCalls, 1); XCTAssertNil(f.store.setupIssue)
        f.time += 60; f.store.tick(); XCTAssertTrue(f.store.dimmed)
        XCTAssertEqual(f.sensors.listens, 1); XCTAssertEqual(f.sensors.checks, 0)
        for _ in 0..<12 { f.sensors.level?(-60) }
        XCTAssertTrue(f.store.receivingAudio)
        f.sensors.level?(-20); f.sensors.level?(-20)
        XCTAssertEqual(f.sensors.checks, 1)
        f.sensors.results[0](true); XCTAssertEqual(f.brightness, 0.63)
    }
    @MainActor func testCameraPermissionRequiredOnlyForDepthMode() {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sensors.cameraAllowed = false; f.sleep()
        XCTAssertFalse(f.store.dimmed); XCTAssertTrue(f.store.setupIssue?.contains("Camera") == true)
        f.store.mode = .sound; f.store.dim()
        XCTAssertTrue(f.store.dimmed); XCTAssertEqual(f.sensors.listens, 1)
        for _ in 0..<12 { f.sensors.level?(-60) }
        f.sensors.level?(-20); f.sensors.level?(-20)
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.sensors.checks, 0)
    }
    @MainActor func testMicrophoneStartErrorAndMissingBuffersRestoreBrightness() async throws {
        let f = StandbyFixture(); defer { f.cleanup() }
        f.sensors.failToStart = true; f.sleep()
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        XCTAssertTrue(f.store.message.contains("could not start"))
        f.sensors.failToStart = false
        await f.store.requestPermissions(); f.store.dim()
        XCTAssertTrue(f.store.dimmed); XCTAssertFalse(f.store.receivingAudio)
        try await Task.sleep(for: .milliseconds(4200))
        XCTAssertFalse(f.store.dimmed); XCTAssertEqual(f.brightness, 0.63)
        XCTAssertTrue(f.store.message.contains("No microphone input"))
    }
}
