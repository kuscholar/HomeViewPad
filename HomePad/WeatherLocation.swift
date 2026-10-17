import CoreLocation
import SwiftUI

/// One foreground, city-scale fix; no background tracking and no manager in demo mode.
@MainActor final class WeatherLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var message = "Philadelphia is used until your location is available."
    private var manager: CLLocationManager?
    private let geocoder = CLGeocoder()
    private weak var weather: WeatherStore?
    private var locating = false
    private var lastAttempt: Date?
    private var generation = UUID()
    private var geocodeTask: Task<Void, Never>?

    func update(_ weather: WeatherStore, force: Bool = false) {
        guard !weather.demo, !weather.isPreview, weather.followsLocation else { stop(); return }
        self.weather = weather
        if force { lastAttempt = nil }
        if manager == nil {
            let manager = CLLocationManager()
            manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            self.manager = manager; manager.delegate = self
        }
        authorizeOrLocate()
    }
    private func authorizeOrLocate() {
        guard let weather, !weather.demo, weather.followsLocation, let manager else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            message = "Allow location to show weather for your city."
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !locating, lastAttempt.map({ Date.now.timeIntervalSince($0) >= 900 }) ?? true else { return }
            lastAttempt = .now; locating = true; message = "Finding your city…"
            manager.requestLocation()
        case .denied, .restricted:
            weather.applyLocatedCity(.philadelphia)
            message = "Location is off. Using Philadelphia; you can also choose a city below."
        @unknown default: break
        }
    }
    func stop() {
        generation = UUID(); geocodeTask?.cancel(); geocodeTask = nil; geocoder.cancelGeocode()
        if locating { lastAttempt = nil }
        manager?.stopUpdatingLocation(); locating = false; weather = nil
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizeOrLocate() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let weather = self.weather, !weather.demo, weather.followsLocation,
                  let location = locations.last, location.horizontalAccuracy >= 0,
                  abs(location.timestamp.timeIntervalSinceNow) < 600 else { return }
            let id = self.generation
            self.geocodeTask = Task {
                let place = try? await self.geocoder.reverseGeocodeLocation(location).first
                guard !Task.isCancelled, self.generation == id, !weather.demo, weather.followsLocation else { return }
                // Weather needs a city-scale coordinate, not the precise GPS point.
                let city = WeatherCity(id: -1, name: place?.locality ?? place?.subAdministrativeArea ?? "Current location",
                                       latitude: (location.coordinate.latitude * 100).rounded() / 100,
                                       longitude: (location.coordinate.longitude * 100).rounded() / 100,
                                       admin1: place?.administrativeArea, country: place?.country)
                weather.applyLocatedCity(city)
                self.locating = false; self.message = "Using your current city · \(city.name)"
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let weather = self.weather, !weather.demo, weather.followsLocation else { return }
            weather.applyLocatedCity(.philadelphia)
            self.locating = false; self.message = "Location unavailable. Using Philadelphia."
        }
    }
}
