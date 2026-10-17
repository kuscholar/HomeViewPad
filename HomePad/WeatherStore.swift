import Foundation
import CoreLocation
import WeatherKit
import SwiftUI

struct WeatherCity: Codable, Identifiable, Equatable {
    static let philadelphia = WeatherCity(id: 4560349, name: "Philadelphia", latitude: 39.9526, longitude: -75.1652, admin1: "Pennsylvania", country: "United States")
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    var admin1: String? = nil
    var country: String? = nil
    var detail: String { [admin1, country].compactMap { $0 }.joined(separator: ", ") }
    var valid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
}

enum WeatherProvider: String, CaseIterable {
    case weatherKit
    #if DEBUG
    case openMeteo
    #endif

    var name: String {
        switch self {
        case .weatherKit: return "Apple WeatherKit"
        #if DEBUG
        case .openMeteo: return "Open-Meteo"
        #endif
        }
    }
    var privacyDescription: String {
        switch self {
        case .weatherKit: return "Weather is provided by Apple Weather through WeatherKit. City searches and the selected city's coordinates are sent to Apple."
        #if DEBUG
        case .openMeteo: return "Weather-model estimates are provided by Open-Meteo. City searches and the selected city's coordinates are sent to Open-Meteo. This free endpoint is for non-commercial development only."
        #endif
        }
    }
    var unavailableMessage: String {
        switch self {
        case .weatherKit: return "Apple Weather is unavailable. Check your connection and try again. This build also needs WeatherKit enabled for its signing account. Previous readings are marked as cached."
        #if DEBUG
        case .openMeteo: return "Open-Meteo is unavailable. Check your connection and try again. Previous readings are marked as cached."
        #endif
        }
    }
    func makeClient() -> any WeatherProviding {
        switch self {
        case .weatherKit: return AppleWeatherClient()
        #if DEBUG
        case .openMeteo: return OpenMeteoClient()
        #endif
        }
    }
    static func initial(defaults: UserDefaults) -> WeatherProvider {
        #if DEBUG
        return defaults.string(forKey: "debugWeatherProvider").flatMap(WeatherProvider.init(rawValue:)) ?? .openMeteo
        #else
        return .weatherKit // Ignore Debug preferences, including a previously selected provider.
        #endif
    }
}

struct WeatherSource: Equatable {
    let lightMarkURL: URL
    let darkMarkURL: URL
    let legalURL: URL
}

struct WeatherReading: Equatable {
    let temperature: Double
    let high: Double
    let low: Double
    let condition: String
    let symbol: String
    let date: Date
    var source: WeatherSource? = nil // Apple supplies its own mark and legal-source URL.
    var provider: WeatherProvider = .weatherKit
    var hasAttribution: Bool {
        switch provider {
        case .weatherKit: return source != nil
        #if DEBUG
        case .openMeteo: return true
        #endif
        }
    }
    static let demo = WeatherReading(temperature: 12.2222, high: 13.8889, low: 9.4444,
                                    condition: "Partly Cloudy", symbol: "cloud.sun.fill",
                                    date: Date(timeIntervalSince1970: 1791981300))
    func degrees(_ value: Double, fahrenheit: Bool) -> String {
        String(format: "%.0f°", fahrenheit ? value * 9 / 5 + 32 : value)
    }
}

protocol WeatherProviding {
    func search(_ name: String) async throws -> [WeatherCity]
    func fetch(_ city: WeatherCity) async throws -> WeatherReading
}

enum WeatherError: Error { case invalidData }

/// Native Apple services only. No API keys or REST signing secrets in the app.
actor AppleWeatherClient: WeatherProviding {
    private var source: WeatherSource?

    func search(_ name: String) async throws -> [WeatherCity] {
        let geocoder = CLGeocoder()
        let places = try await geocoder.geocodeAddressString(name)
        try Task.checkCancellation()
        var seen = Set<Int>()
        return places.compactMap { place in
            guard let coordinate = place.location?.coordinate else { return nil }
            let latitude = (coordinate.latitude * 100).rounded() / 100
            let longitude = (coordinate.longitude * 100).rounded() / 100
            // Stable coordinate-based IDs, independent of GeoNames and Swift's randomized hash.
            let id = Int((latitude + 90) * 100) * 36001 + Int((longitude + 180) * 100)
            let city = WeatherCity(id: id, name: place.locality ?? place.subAdministrativeArea ?? place.name ?? name,
                                   latitude: latitude, longitude: longitude,
                                   admin1: place.administrativeArea, country: place.country)
            return city.valid && seen.insert(id).inserted ? city : nil
        }
    }

    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        guard city.valid else { throw WeatherError.invalidData }
        let service = WeatherService.shared
        let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
        let (current, forecast) = try await service.weather(for: location, including: .current, .daily)
        try Task.checkCancellation()
        guard let today = forecast.first else { throw WeatherError.invalidData }
        if source == nil {
            let attribution = try await service.attribution
            source = WeatherSource(lightMarkURL: attribution.combinedMarkLightURL,
                                   darkMarkURL: attribution.combinedMarkDarkURL, legalURL: attribution.legalPageURL)
        }
        guard let source else { throw WeatherError.invalidData }
        return try Self.reading(temperature: current.temperature, high: today.highTemperature,
                                low: today.lowTemperature, condition: current.condition.description,
                                symbol: current.symbolName, date: current.date, source: source)
    }

    nonisolated static func reading(temperature: Measurement<UnitTemperature>, high: Measurement<UnitTemperature>,
                                    low: Measurement<UnitTemperature>, condition: String, symbol: String,
                                    date: Date, source: WeatherSource) throws -> WeatherReading {
        let temperature = temperature.converted(to: .celsius).value
        let high = high.converted(to: .celsius).value
        let low = low.converted(to: .celsius).value
        guard [temperature, high, low, date.timeIntervalSince1970].allSatisfy(\.isFinite), high >= low else {
            throw WeatherError.invalidData
        }
        return WeatherReading(temperature: temperature, high: high, low: low,
                              condition: condition, symbol: symbol, date: date, source: source)
    }
}

#if DEBUG
/// Explicit UI-test fixture, unavailable in Release. Never a live-service fallback.
private struct WeatherPreviewClient: WeatherProviding {
    func search(_ name: String) async throws -> [WeatherCity] { [.philadelphia] }
    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        var reading = WeatherReading.demo
        // Exercise the mark placeholder without any external image request.
        reading.source = WeatherSource(lightMarkURL: URL(fileURLWithPath: "/weather-test-light.png"),
                                       darkMarkURL: URL(fileURLWithPath: "/weather-test-dark.png"),
                                       legalURL: URL(string: "https://example.invalid/weather-test-sources")!)
        return reading
    }
}
#endif

/// Use Apple's supplied mark and attribution URL wherever real weather is displayed.
struct AppleWeatherAttribution: View {
    let source: WeatherSource
    var onDark: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Link(destination: source.legalURL) {
            HStack(spacing: 6) {
                AsyncImage(url: onDark || colorScheme == .dark ? source.lightMarkURL : source.darkMarkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    HStack(spacing: 3) { Image(systemName: "apple.logo"); Text("Weather") }
                        .font(.system(size: 12, weight: .medium)).fixedSize()
                }.frame(width: 80, height: 18)
                Text("Data sources").font(.caption2)
            }.foregroundStyle(onDark ? Color.white : Color.primary)
                .padding(.vertical, 6)
        }.accessibilityLabel("Apple Weather, data sources").accessibilityIdentifier("appleWeatherAttribution")
    }
}

struct WeatherAttributionLink: View {
    let reading: WeatherReading
    var onDark: Bool = false
    var body: some View {
        switch reading.provider {
        case .weatherKit:
            if let source = reading.source { AppleWeatherAttribution(source: source, onDark: onDark) }
        #if DEBUG
        case .openMeteo:
            Link("Weather by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                .font(.caption2).foregroundStyle(onDark ? Color.white : Color.primary)
                .padding(.vertical, 6).accessibilityIdentifier("openMeteoAttribution")
        #endif
        }
    }
}

@MainActor final class WeatherStore: ObservableObject {
    @Published private(set) var city: WeatherCity?
    @Published private(set) var reading: WeatherReading?
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var demo: Bool
    @Published private(set) var followsLocation: Bool
    @Published var fahrenheit: Bool { didSet { defaults.set(fahrenheit, forKey: "weatherFahrenheit") } }
    @Published private(set) var provider: WeatherProvider
    private var client: any WeatherProviding
    private let clientFactory: (WeatherProvider) -> any WeatherProviding
    private var providerGeneration = UUID()
    let isPreview: Bool
    private let defaults: UserDefaults
    private var requestID = UUID()
    private var lastAttempt: Date?
    init(defaults: UserDefaults = .standard, client: (any WeatherProviding)? = nil, demo: Bool = false,
         clientFactory: @escaping (WeatherProvider) -> any WeatherProviding = { $0.makeClient() }) {
        self.defaults = defaults; self.demo = demo; self.clientFactory = clientFactory
        #if DEBUG
        isPreview = client == nil && ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--weather-preview")
        let initialProvider: WeatherProvider = isPreview ? .weatherKit : WeatherProvider.initial(defaults: defaults)
        provider = initialProvider
        self.client = client ?? (isPreview ? WeatherPreviewClient() : clientFactory(initialProvider))
        #else
        isPreview = false
        provider = .weatherKit
        self.client = client ?? clientFactory(.weatherKit)
        #endif
        followsLocation = defaults.object(forKey: "weatherFollowsLocation") as? Bool ?? true
        city = .philadelphia
        fahrenheit = defaults.object(forKey: "weatherFahrenheit") as? Bool ?? true
        if !followsLocation, let data = defaults.data(forKey: "weatherCity"), let stored = try? JSONDecoder().decode(WeatherCity.self, from: data), stored.valid { city = stored }
    }
    #if DEBUG
    func setProvider(_ value: WeatherProvider) {
        guard value != provider, !isPreview else { return }
        invalidate(); providerGeneration = UUID()
        client = clientFactory(value)
        provider = value
        defaults.set(value.rawValue, forKey: "debugWeatherProvider")
    }
    #endif
    func search(_ name: String) async throws -> [WeatherCity] {
        guard !demo else { return [] }
        let generation = providerGeneration
        let results = try await client.search(name)
        try Task.checkCancellation()
        guard generation == providerGeneration, !demo else { throw CancellationError() }
        return results
    }
    func setDemo(_ value: Bool) {
        guard value != demo else { return }
        demo = value; providerGeneration = UUID(); invalidate()
    }
    private func invalidate() { requestID = UUID(); reading = nil; loading = false; failed = false; lastAttempt = nil }
    func select(_ value: WeatherCity?) {
        guard value == nil || value!.valid else { return }
        followsLocation = false; defaults.set(false, forKey: "weatherFollowsLocation")
        invalidate(); city = value
        if let value, let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "weatherCity") }
        else { defaults.removeObject(forKey: "weatherCity") }
    }
    func enableLocation() {
        followsLocation = true; defaults.set(true, forKey: "weatherFollowsLocation")
    }
    func applyLocatedCity(_ city: WeatherCity) {
        guard followsLocation, !demo, city.valid, self.city != city else { return }
        invalidate(); self.city = city
        // Keep automatically located coordinates in memory only. Relaunch falls back to Philadelphia.
    }
    func refresh(force: Bool = false, now: Date = .now) async {
        guard !demo, let city, !loading else { return }
        if !force, let lastAttempt, (reading != nil || failed), now.timeIntervalSince(lastAttempt) < (failed ? 120 : 900) { return }
        let id = UUID(); requestID = id; lastAttempt = now; loading = true
        defer { if requestID == id { loading = false } }
        do {
            let result = try await client.fetch(city)
            if Task.isCancelled { if requestID == id { lastAttempt = nil }; return }
            guard requestID == id, !demo, self.city == city else { return }
            reading = result; failed = false
        } catch {
            if Task.isCancelled { if requestID == id { lastAttempt = nil }; return }
            guard requestID == id, !demo else { return }
            failed = true // Keep a previous reading, explicitly marked as cached/offline.
        }
    }
    func stale(at date: Date = .now) -> Bool { reading.map { date.timeIntervalSince($0.date) > 3600 } ?? false }
}

struct WeatherPanel: View {
    @ObservedObject var weather: WeatherStore
    @ObservedObject var location: WeatherLocation
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var results: [WeatherCity] = []
    @State private var searching = false
    @State private var searchMessage: String?
    var body: some View {
        Form {
            if weather.isPreview {
                Section { Text("TEST WEATHER · Simulated data, not a live Apple Weather result.").accessibilityIdentifier("weatherPreviewNotice") }
            }
            if weather.demo {
                Section { Text("DEMO · Fixed sample weather. Leave demo mode in Settings to use live weather.").accessibilityIdentifier("weatherDemoNotice") }
            } else {
                Section("Location") {
                    Button("Use current location") { weather.enableLocation(); location.update(weather, force: true) }.accessibilityIdentifier("useWeatherLocation")
                    Text(weather.followsLocation ? location.message : "Using your chosen city.").font(.footnote).accessibilityIdentifier("weatherLocationStatus")
                }
                Section("City") {
                    if let city = weather.city {
                        Text(city.name).font(.headline).accessibilityIdentifier("weatherSelectedCity")
                        Text(city.detail).foregroundStyle(.secondary)
                        if let reading = weather.reading {
                            Text("\(reading.degrees(reading.temperature, fahrenheit: weather.fahrenheit)) · \(reading.condition)").accessibilityIdentifier("weatherLiveReading")
                            Text("Weather time: \(reading.date.formatted(date: .abbreviated, time: .shortened))").font(.footnote)
                        }
                        if weather.failed { Text(weather.provider.unavailableMessage).accessibilityIdentifier("weatherUnavailable") }
                        Button("Refresh weather") { Task { await weather.refresh(force: true) } }.disabled(weather.loading).accessibilityIdentifier("refreshWeather")
                        Button("Use Philadelphia") { weather.select(.philadelphia) }.accessibilityIdentifier("removeWeatherCity")
                    }
                    TextField("Search city", text: $query).textInputAutocapitalization(.words).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("weatherCitySearch")
                    if searching || weather.loading { ProgressView() }
                    ForEach(results) { city in
                        Button { weather.select(city); query = "" } label: {
                            VStack(alignment: .leading) { Text(city.name); Text(city.detail).font(.caption).foregroundStyle(.secondary) }
                        }.accessibilityIdentifier("weatherCity-\(city.id)")
                    }
                    if let searchMessage { Text(searchMessage).foregroundStyle(.secondary) }
                }
            }
            Section("Temperature") {
                Picker("Units", selection: $weather.fahrenheit) { Text("°C").tag(false); Text("°F").tag(true) }.pickerStyle(.segmented)
            }
            #if DEBUG
            if !weather.demo, !weather.isPreview {
                Section("Debug weather provider") {
                    Picker("Provider", selection: Binding(get: { weather.provider }, set: { weather.setProvider($0) })) {
                        Text("Open-Meteo").tag(WeatherProvider.openMeteo)
                        Text("WeatherKit").tag(WeatherProvider.weatherKit)
                    }.pickerStyle(.segmented).accessibilityIdentifier("weatherProviderPicker")
                    Text("Debug only. Release always uses Apple WeatherKit. Switching clears the previous weather; failures never switch providers automatically.").font(.footnote)
                }
            }
            #endif
            Section("Weather data") {
                if !weather.demo, let reading = weather.reading { WeatherAttributionLink(reading: reading) }
                #if DEBUG
                if !weather.demo, weather.provider == .openMeteo {
                    Link("City names by GeoNames", destination: URL(string: "https://www.geonames.org/")!)
                }
                #endif
                Text(weather.provider.privacyDescription).font(.footnote).accessibilityIdentifier("weatherProviderDisclosure")
                Text("Refreshes every 15 minutes while visible. With your permission, Apple Location Services finds your city. Automatically detected coordinates sent for weather are rounded to about 1 km. No background location tracking.").font(.footnote)
            }
        }.task(id: "\(query)-\(weather.provider.rawValue)-\(weather.demo)") {
            results = []; searchMessage = nil; searching = false
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !weather.demo, term.count >= 2 else { return }
            do {
                try await Task.sleep(for: .milliseconds(400)); searching = true
                let found = try await weather.search(term)
                guard !Task.isCancelled else { return }
                results = found; searching = false
                if found.isEmpty { searchMessage = "No cities found. Try a nearby city or include the country." }
            } catch {
                guard !Task.isCancelled else { return }
                searching = false; searchMessage = "Search unavailable. Check your connection and try again."
            }
        }
    }
}
