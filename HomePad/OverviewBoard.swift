import SwiftUI

/// Four fixed, opaque widgets. PhotoKit is shared with Home and the photo wall.
struct OverviewBoard: View {
    @ObservedObject var photos: PhotoLibraryStore
    @ObservedObject var weather: WeatherStore
    let demoDate: Date?
    let side: CGFloat
    let chooseAlbum: () -> Void
    let configureWeather: () -> Void
    private let yellow = Color(red: 1, green: 0.77, blue: 0.16)

    var body: some View {
        let inset = side * 0.065
        let gap = side * 0.055
        let cell = (side - inset * 2 - gap) / 2
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                dateWidget(size: cell)
                AnalogHomeClock(date: demoDate, numbered: true, monochrome: true)
                    .padding(cell * 0.025).frame(width: cell, height: cell)
                    .background(.black)
                    .accessibilityIdentifier("overviewClock")
            }
            HStack(spacing: gap) {
                albumWidget(size: cell)
                weatherWidget(size: cell)
            }
        }
        .padding(inset).frame(width: side, height: side).background(.black)
        .foregroundStyle(.white).buttonStyle(.plain)
        .overlay(alignment: .bottomLeading) {
            if demoDate != nil || weather.isPreview {
                Text(weather.isPreview ? "TEST WEATHER · Simulated data" : "DEMO").font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(.white.opacity(0.65)).padding(.leading, inset).padding(.bottom, 5)
                    .accessibilityIdentifier(weather.isPreview ? "weatherPreviewBadge" : "demoBadge")
            }
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("overviewBoard")
    }

    private func dateWidget(size: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = demoDate ?? context.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: size * 0.035) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated))).foregroundStyle(yellow)
                    Text(date.formatted(.dateTime.month(.abbreviated))).foregroundStyle(.gray)
                }.font(.system(size: size * 0.105, weight: .medium)).lineLimit(1).minimumScaleFactor(0.6)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: size * 0.65, weight: .light))
                    .tracking(-size * 0.035).lineLimit(1).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, size * 0.07).frame(width: size, height: size, alignment: .leading)
            .background(.black)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        }.accessibilityIdentifier("overviewDate")
    }

    private func albumWidget(size: CGFloat) -> some View {
        Button(action: chooseAlbum) {
            VStack(alignment: .leading, spacing: size * 0.025) {
                ZStack {
                    Color(white: 0.08)
                    FadingPhoto(frame: photos.frame)
                    if photos.image == nil {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: size * 0.14, weight: .light)).foregroundStyle(.gray)
                    }
                }.frame(width: size * 0.53, height: size * 0.53)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.015))
                Text(photos.image == nil ? "Your photos" : photos.albumTitle)
                    .font(.system(size: size * 0.063, weight: .medium)).lineLimit(1)
                Text(photos.image == nil ? "Choose an album" : "Favorite moments")
                    .font(.system(size: size * 0.05)).foregroundStyle(.gray).lineLimit(1)
                Label("Albums", systemImage: "photo.stack")
                    .font(.system(size: size * 0.052, weight: .medium))
                    .padding(.horizontal, size * 0.04).padding(.vertical, size * 0.025)
                    .background(Color(white: 0.16), in: Capsule())
                    .padding(.top, size * 0.012)
            }.frame(width: size * 0.86, alignment: .leading)
                .frame(width: size, height: size).background(.black)
                .contentShape(Rectangle())
        }.accessibilityLabel("Albums, \(photos.albumTitle)")
            .accessibilityValue(photos.image == nil ? "No photo selected" : photos.photoCount > 0 ? "Photo \(photos.position + 1) of \(photos.photoCount)" : "Selected photo")
            .accessibilityIdentifier("overviewAlbum")
            .accessibilityAction(named: "Next photo") { photos.next() }
    }

    private func weatherWidget(size: CGFloat) -> some View {
        let demo = demoDate != nil
        let reading = demo ? WeatherReading.demo : weather.reading
        let fahrenheit = demo ? true : weather.fahrenheit
        let status = demo ? "Partly Cloudy" : weather.failed ? (reading == nil ? "Unavailable" : "Offline · cached") : weather.stale() ? "Outdated · tap to refresh" : reading?.condition ?? (weather.city == nil ? "Choose a city" : "Loading…")
        return VStack(spacing: 0) {
            Button(action: configureWeather) {
                VStack(alignment: .leading, spacing: size * 0.015) {
                    Text(demo ? "Philadelphia" : weather.city?.name ?? "Weather")
                        .font(.system(size: size * 0.063, weight: .medium)).foregroundStyle(yellow)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(reading.map { $0.degrees($0.temperature, fahrenheit: fahrenheit) } ?? "—°")
                        .font(.system(size: size * 0.40, weight: .light)).tracking(-size * 0.02)
                        .lineLimit(1).minimumScaleFactor(0.65)
                    Image(systemName: reading?.symbol ?? "cloud")
                        .symbolRenderingMode(.palette).foregroundStyle(.white, yellow)
                        .font(.system(size: size * 0.085))
                    Text(status).font(.system(size: size * 0.058)).lineLimit(1).minimumScaleFactor(0.6)
                    Text(reading.map { "H:\($0.degrees($0.high, fahrenheit: fahrenheit)) L:\($0.degrees($0.low, fahrenheit: fahrenheit))" } ?? "Tap to configure")
                        .font(.system(size: size * 0.052)).foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }.frame(width: size * 0.86, alignment: .leading)
                    .frame(width: size, height: size - (!demo && reading?.source != nil ? 30 : 0))
                    .background(.black).contentShape(Rectangle())
            }.accessibilityElement(children: .combine).accessibilityIdentifier("overviewWeather")
            if !demo, let source = reading?.source {
                AppleWeatherAttribution(source: source, onDark: true).frame(height: 30)
            }
        }.frame(width: size, height: size).background(.black)
    }
}
