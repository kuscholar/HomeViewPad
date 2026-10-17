import XCTest
@testable import HomePad

private actor WeatherStub: WeatherProviding {
    var calls = 0
    var searchCalls = 0
    var pendingSearch: CheckedContinuation<[WeatherCity], Error>?
    var holdSearch = false
    let searchStarted: (() -> Void)?
    var fail = false
    var hold = false
    var pending: CheckedContinuation<WeatherReading, Error>?
    let started: (() -> Void)?
    init(started: (() -> Void)? = nil, searchStarted: (() -> Void)? = nil) { self.started = started; self.searchStarted = searchStarted }
    func search(_ name: String) async throws -> [WeatherCity] {
        searchCalls += 1; searchStarted?()
        if holdSearch { return try await withCheckedThrowingContinuation { pendingSearch = $0 } }
        return [.philadelphia]
    }
    func setHoldSearch() { holdSearch = true }
    func finishSearch() { pendingSearch?.resume(returning: [.philadelphia]); pendingSearch = nil }
    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        calls += 1; started?()
        if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
        if fail { throw URLError(.notConnectedToInternet) }
        return .demo
    }
    func setFailure() { fail = true }
    func setHold() { hold = true }
    func finish() { pending?.resume(returning: .demo); pending = nil }
}

final class WeatherTests: XCTestCase {
    private let source = WeatherSource(lightMarkURL: URL(string: "https://example.com/light.png")!,
                                       darkMarkURL: URL(string: "https://example.com/dark.png")!,
                                       legalURL: URL(string: "https://example.com/sources")!)
    func testAppleWeatherUnitsConditionSymbolAndAttribution() throws {
        let date = Date(timeIntervalSince1970: 1792032300)
        let reading = try AppleWeatherClient.reading(temperature: .init(value: 69.8, unit: .fahrenheit),
            high: .init(value: 300, unit: .kelvin), low: .init(value: 18.1, unit: .celsius),
            condition: "Clear", symbol: "moon.stars.fill", date: date, source: source)
        XCTAssertEqual(reading.temperature, 21, accuracy: 0.001)
        XCTAssertEqual(reading.high, 26.85, accuracy: 0.001)
        XCTAssertEqual(reading.degrees(reading.temperature, fahrenheit: true), "70°")
        XCTAssertEqual(reading.degrees(reading.temperature, fahrenheit: false), "21°")
        XCTAssertEqual(reading.condition, "Clear")
        XCTAssertEqual(reading.symbol, "moon.stars.fill")
        XCTAssertEqual(reading.date, date)
        XCTAssertEqual(reading.source, source)
    }
    func testAppleWeatherRejectsInvalidValues() {
        for (temperature, high, low) in [(Double.nan, 20.0, 10.0), (15.0, Double.infinity, 10.0), (15.0, 10.0, 20.0)] {
            XCTAssertThrowsError(try AppleWeatherClient.reading(temperature: .init(value: temperature, unit: .celsius),
                high: .init(value: high, unit: .celsius), low: .init(value: low, unit: .celsius),
                condition: "Cloudy", symbol: "cloud.fill", date: .now, source: source))
        }
    }
    @MainActor func testUnavailableServiceNeverSubstitutesSampleWeatherAndRetriesAreThrottled() async {
        let name = "WeatherTests.\(UUID())", stub = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: stub)
        await stub.setFailure()
        let now = Date.now
        await store.refresh(now: now)
        await store.refresh(now: now.addingTimeInterval(60))
        var calls = await stub.calls
        XCTAssertEqual(calls, 1); XCTAssertTrue(store.failed); XCTAssertNil(store.reading)
        await store.refresh(now: now.addingTimeInterval(121))
        calls = await stub.calls; XCTAssertEqual(calls, 2)
    }
    @MainActor func testDemoDoesNotRequestWeatherAndCitySelectionPersists() async {
        let name = "WeatherTests.\(UUID())", stub = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: stub, demo: true)
        XCTAssertEqual(store.city, .philadelphia); XCTAssertTrue(store.followsLocation)
        await store.refresh(force: true)
        let calls = await stub.calls; XCTAssertEqual(calls, 0); XCTAssertNil(store.reading)
        store.select(WeatherCity(id: 5128581, name: "New York", latitude: 40.71, longitude: -74))
        store.fahrenheit = false
        let restored = WeatherStore(defaults: defaults, client: stub)
        XCTAssertEqual(restored.city?.name, "New York"); XCTAssertFalse(restored.followsLocation)
        XCTAssertFalse(restored.fahrenheit)
        restored.enableLocation()
        let automatic = WeatherStore(defaults: defaults, client: stub)
        XCTAssertEqual(automatic.city, .philadelphia) // Never persist an automatically detected GPS point.
    }
    @MainActor func testRefreshThrottlesAndOfflineReadingIsMarked() async {
        let name = "WeatherTests.\(UUID())", stub = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: stub)
        let now = WeatherReading.demo.date
        await store.refresh(now: now)
        await store.refresh(now: now.addingTimeInterval(60))
        var calls = await stub.calls; XCTAssertEqual(calls, 1)
        await stub.setFailure()
        await store.refresh(force: true, now: now.addingTimeInterval(900))
        calls = await stub.calls; XCTAssertEqual(calls, 2)
        XCTAssertTrue(store.failed); XCTAssertEqual(store.reading, .demo)
        XCTAssertTrue(store.stale(at: now.addingTimeInterval(3601)))
        XCTAssertFalse(store.loading)
    }
    @MainActor func testLateResponseCannotReplaceAnotherCityOrDemoMode() async {
        let name = "WeatherTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let started = expectation(description: "request started")
        let stub = WeatherStub(started: { started.fulfill() }); await stub.setHold()
        let store = WeatherStore(defaults: defaults, client: stub)
        let task = Task { await store.refresh() }
        await fulfillment(of: [started], timeout: 2)
        store.select(WeatherCity(id: 1, name: "Other city", latitude: 0, longitude: 0))
        store.setDemo(true)
        await stub.finish(); await task.value
        XCTAssertNil(store.reading); XCTAssertEqual(store.city?.name, "Other city")
        XCTAssertFalse(store.loading); XCTAssertFalse(store.failed)
    }
    @MainActor func testLocationUpdatesCannotOverrideManualChoiceOrDemo() {
        let name = "WeatherTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: WeatherStub())
        let detected = WeatherCity(id: -1, name: "Detected city", latitude: 40, longitude: -75)
        store.applyLocatedCity(detected); XCTAssertEqual(store.city, detected)
        store.select(.philadelphia); store.applyLocatedCity(detected)
        XCTAssertEqual(store.city, .philadelphia)
        store.enableLocation(); store.setDemo(true); store.applyLocatedCity(detected)
        XCTAssertEqual(store.city, .philadelphia)
    }
    #if DEBUG
    func testOpenMeteoDecodingAndNightSymbols() throws {
        let json = #"{"current":{"time":1792032300,"temperature_2m":21.0,"weather_code":0,"is_day":0},"daily":{"temperature_2m_max":[26.8],"temperature_2m_min":[18.1]}}"#
        let reading = try OpenMeteoClient.decode(Data(json.utf8))
        XCTAssertEqual(reading.provider, .openMeteo); XCTAssertNil(reading.source)
        XCTAssertTrue(reading.hasAttribution)
        XCTAssertEqual(reading.degrees(reading.temperature, fahrenheit: true), "70°")
        XCTAssertEqual(reading.condition, "Clear"); XCTAssertEqual(reading.symbol, "moon.stars.fill")
        for invalid in [json.replacingOccurrences(of: "[26.8]", with: "[null]"),
                        json.replacingOccurrences(of: "[18.1]", with: "[]"),
                        json.replacingOccurrences(of: "[26.8]", with: "[10.0]"), "{}"] {
            XCTAssertThrowsError(try OpenMeteoClient.decode(Data(invalid.utf8)))
        }
        XCTAssertEqual(OpenMeteoClient.forecastURL(.philadelphia).host, "api.open-meteo.com")
    }
    @MainActor func testDebugProviderDefaultPersistenceAndCacheIsolation() async {
        let name = "WeatherTests.\(UUID())", first = WeatherStub(), second = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, clientFactory: { $0 == .openMeteo ? first : second })
        XCTAssertEqual(store.provider, .openMeteo)
        store.select(.philadelphia); store.fahrenheit = false
        await store.refresh(); XCTAssertNotNil(store.reading)
        await first.setFailure(); await store.refresh(force: true); XCTAssertTrue(store.failed)
        store.setProvider(.weatherKit)
        XCTAssertNil(store.reading); XCTAssertFalse(store.failed); XCTAssertFalse(store.loading)
        XCTAssertEqual(store.city, .philadelphia); XCTAssertFalse(store.fahrenheit); XCTAssertFalse(store.followsLocation)
        await store.refresh(); let count = await second.calls; XCTAssertEqual(count, 1)
        XCTAssertEqual(WeatherStore(defaults: defaults, client: second).provider, .weatherKit)
        defaults.set("invalid", forKey: "debugWeatherProvider")
        XCTAssertEqual(WeatherStore(defaults: defaults, client: first).provider, .openMeteo)
    }
    @MainActor func testProviderChangeRejectsOldWeatherAndSearchEvenAfterSwitchingBack() async {
        let name = "WeatherTests.\(UUID())"
        let isolated = UserDefaults(suiteName: name)!
        defer { isolated.removePersistentDomain(forName: name) }
        let fetched = expectation(description: "old provider fetch started")
        let searched = expectation(description: "old provider search started")
        let old = WeatherStub(started: { fetched.fulfill() }, searchStarted: { searched.fulfill() })
        let replacement = WeatherStub()
        await old.setHold(); await old.setHoldSearch()
        let store = WeatherStore(defaults: isolated, clientFactory: { $0 == .openMeteo ? old : replacement })
        let fetch = Task { await store.refresh() }
        let search = Task { try await store.search("Philadelphia") }
        await fulfillment(of: [fetched, searched], timeout: 2)
        store.setProvider(.weatherKit); store.setProvider(.openMeteo)
        await old.finish(); await old.finishSearch(); await fetch.value
        XCTAssertNil(store.reading); XCTAssertFalse(store.failed)
        do { _ = try await search.value; XCTFail("An old provider's city results must be discarded") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    @MainActor func testDemoProviderSelectionDoesNotFetchOrSearch() async throws {
        let name = "WeatherTests.\(UUID())"
        let isolated = UserDefaults(suiteName: name)!, stub = WeatherStub()
        defer { isolated.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: isolated, demo: true, clientFactory: { _ in stub })
        store.setProvider(.weatherKit); await store.refresh(force: true)
        let cities = try await store.search("Philadelphia")
        XCTAssertTrue(cities.isEmpty)
        let fetches = await stub.calls, searches = await stub.searchCalls
        XCTAssertEqual(fetches, 0); XCTAssertEqual(searches, 0); XCTAssertNil(store.reading)
    }
    #else
    @MainActor func testReleaseIgnoresDebugProviderPreference() {
        let name = "WeatherTests.\(UUID())"
        let isolated = UserDefaults(suiteName: name)!
        defer { isolated.removePersistentDomain(forName: name) }
        isolated.set("openMeteo", forKey: "debugWeatherProvider")
        XCTAssertEqual(WeatherProvider.allCases, [.weatherKit])
        XCTAssertEqual(WeatherProvider.initial(defaults: isolated), .weatherKit)
        XCTAssertEqual(WeatherStore(defaults: isolated, client: WeatherStub()).provider, .weatherKit)
    }
    #endif

}
