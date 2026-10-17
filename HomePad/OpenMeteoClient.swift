#if DEBUG
import Foundation

/// Development-only provider. Neither these endpoints nor this client exist in Release.
struct OpenMeteoClient: WeatherProviding {
    var session: URLSession = URLSession(configuration: .ephemeral)
    static func forecastURL(_ city: WeatherCity) -> URL {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = ["latitude": String(city.latitude), "longitude": String(city.longitude),
                          "current": "temperature_2m,weather_code,is_day", "daily": "temperature_2m_max,temperature_2m_min",
                          "temperature_unit": "celsius", "timezone": "auto", "timeformat": "unixtime", "forecast_days": "1"]
            .sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return url.url!
    }
    private func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 1_000_000 else { throw URLError(.badServerResponse) }
        return data
    }
    func search(_ name: String) async throws -> [WeatherCity] {
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"), URLQueryItem(name: "format", value: "json")]
        struct Response: Decodable { let results: [WeatherCity]? }
        return try JSONDecoder().decode(Response.self, from: await get(url.url!)).results?.filter(\.valid) ?? []
    }
    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        guard city.valid else { throw WeatherError.invalidData }
        return try Self.decode(await get(Self.forecastURL(city)))
    }
    static func decode(_ data: Data) throws -> WeatherReading {
        struct Response: Decodable {
            struct Current: Decodable { let time: Double; let temperature_2m: Double; let weather_code: Int; let is_day: Int }
            struct Daily: Decodable { let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?] }
            let current: Current
            let daily: Daily
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard let high = value.daily.temperature_2m_max.first ?? nil, let low = value.daily.temperature_2m_min.first ?? nil,
              [high, low, value.current.temperature_2m, value.current.time].allSatisfy(\.isFinite), high >= low,
              (0...1).contains(value.current.is_day) else { throw WeatherError.invalidData }
        let display = Conditions(code: value.current.weather_code, isDay: value.current.is_day == 1)
        return WeatherReading(temperature: value.current.temperature_2m, high: high, low: low,
                              condition: display.condition, symbol: display.symbol,
                              date: Date(timeIntervalSince1970: value.current.time), provider: .openMeteo)
    }

    private struct Conditions {
        let code: Int
        let isDay: Bool
        var condition: String {
            switch code {
            case 0: return "Clear"
            case 1: return "Mostly Clear"
            case 2: return "Partly Cloudy"
            case 3: return "Overcast"
            case 45, 48: return "Fog"
            case 51, 53, 55: return "Drizzle"
            case 56, 57, 66, 67: return "Freezing Rain"
            case 61, 63, 65: return "Rain"
            case 71, 73, 75, 77: return "Snow"
            case 80, 81, 82: return "Rain Showers"
            case 85, 86: return "Snow Showers"
            case 95, 96, 99: return "Thunderstorms"
            default: return "Conditions Unknown"
            }
        }
        var symbol: String {
            switch code {
            case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
            case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
            case 3: return "cloud.fill"
            case 45, 48: return "cloud.fog.fill"
            case 51...57: return "cloud.drizzle.fill"
            case 61...67, 80...82: return "cloud.rain.fill"
            case 71...77, 85, 86: return "cloud.snow.fill"
            case 95, 96, 99: return "cloud.bolt.rain.fill"
            default: return "cloud"
            }
        }
    }
}
#endif
