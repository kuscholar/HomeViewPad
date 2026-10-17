import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import HomeKit

private let ink = Color(red: 0.36, green: 0.35, blue: 0.39)
private let lavender = Color(red: 0.78, green: 0.76, blue: 0.88)
private let paper = Color.white

enum Panel: String, Identifiable { case settings, music, agenda, camera, controls, photos, accessory, weather, standby; var id: String { rawValue } }
struct Dashboard: View {
    @StateObject private var home = HomeStore()
    @StateObject private var personal = PersonalStore()
    @StateObject private var audio = AudioStore()
    @StateObject private var photos = PhotoLibraryStore()
    @StateObject private var standby = StandbyStore()
    @StateObject private var weatherLocation = WeatherLocation()
    @StateObject private var weather = WeatherStore(demo: ProcessInfo.processInfo.arguments.contains("--demo") || (!ProcessInfo.processInfo.arguments.contains("--fresh") && UserDefaults.standard.string(forKey: "homeMode") == "demo"))
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("tealWallpaper") private var tealWallpaper = false
    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("showPersonal") private var showPersonal = false
    @State private var didConfigure = false
    @State private var page = DashboardPage.overview
    @State private var navigationVisible = false
    @State private var pageForward = true
    @State private var widgetOffsets = Array(repeating: 0, count: 6)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panel: Panel?
    @State private var sceneToRun: String?
    @State private var selectedCamera: HMAccessory?
    @State private var selectedAccessoryID: UUID?
    @State private var importAudio = false
    @State private var selectedRoom = "All rooms"
    private var demoDate: Date { Date(timeIntervalSince1970: 1791981300) }
    var body: some View {
        GeometryReader { geometry in
            let side = max(1, min(geometry.size.width, geometry.size.height) - 16)
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                ZStack {
                    AmbientWallpaper(teal: tealWallpaper).ignoresSafeArea()
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: tealWallpaper)
                    if page == .overview { Color.black.ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
                    // Only uncovered wallpaper receives taps. Widget taps retain their own actions.
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture(perform: toggleNavigation)
                        .accessibilityLabel("Show navigation").accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("navigationBackdrop")
                    ZStack {
                        Group {
                            if page == .photos {
                                PhotoWall(photos: photos, demoDate: home.demo ? demoDate : nil, navigationVisible: navigationVisible,
                                          chooseAlbum: { panel = .photos }, showNavigation: toggleNavigation)
                            } else { pageContent(side: side).frame(width: side, height: side) }
                        }.frame(width: geometry.size.width, height: geometry.size.height)
                            .id(page).transition(pageTransition)
                    }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .accessibilityAction(named: "Show navigation") { withAnimation(navigationAnimation) { navigationVisible = true } }
                        .accessibilityAction(named: "Next page") { movePage(forward: true) }
                        .accessibilityAction(named: "Previous page") { movePage(forward: false) }
                    if navigationVisible {
                        if landscape {
                            HStack {
                                Spacer(minLength: 0)
                                navigationRail.frame(width: 142).frame(maxHeight: geometry.size.height - 28)
                            }.padding(.trailing, 14)
                                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                        } else {
                            VStack {
                                Spacer(minLength: 0)
                                bottomNavigation.frame(maxWidth: 760).padding(.horizontal, 16).padding(.bottom, max(18, geometry.safeAreaInsets.bottom))
                            }.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }.allowsHitTesting(!standby.dimmed).accessibilityHidden(standby.dimmed)
                if standby.dimmed { standbySurface }
                else if standby.enabled, let issue = standby.setupIssue, page != .settings {
                    VStack {
                        Spacer()
                        Button { panel = .standby } label: {
                            Label(issue, systemImage: "exclamationmark.circle")
                                .font(.footnote).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.foregroundStyle(.primary).accessibilityIdentifier("standbySetupIssue")
                    }.padding(24)
                }
            }.foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(StandbyActivityObserver { if !standby.dimmed { standby.activity() } })
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                    guard !standby.dimmed else { return }
                    standby.activity()
                    switch DashboardSwipe.classify(x: value.translation.width, y: value.translation.height) {
                    case .left: movePage(forward: true)
                    case .right: movePage(forward: false)
                    default: break
                    }
                })
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .overlay { if phase != .active { paper.ignoresSafeArea().overlay { Label("HomeViewPad", systemImage: "house.fill").font(.largeTitle).foregroundStyle(ink) } } }
        .preferredColorScheme(.light)
        .sheet(item: $panel) { panel in
            NavigationStack {
                panelContent(panel).navigationTitle(panel.rawValue.capitalized)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.panel = nil }.accessibilityIdentifier("dismissPanel") } }
            }.modifier(SceneConfirmation(name: $sceneToRun, enabled: true, run: home.runScene))
                .overlay { if phase != .active { paper.ignoresSafeArea().overlay { Text("HomeViewPad").font(.largeTitle) } } }.presentationDetents([.large])
        }
        .modifier(SceneConfirmation(name: $sceneToRun, enabled: panel == nil, run: home.runScene))
        .alert("Home needs attention", isPresented: Binding(get: { home.error != nil }, set: { if !$0 { home.error = nil } })) { Button("OK") { home.error = nil } } message: { Text(home.error ?? "") }
        .task {
            guard !didConfigure else { return }
            didConfigure = true
            if ProcessInfo.processInfo.arguments.contains("--uitesting") { tealWallpaper = false; standby.enabled = false }
            photos.restore()
            if ProcessInfo.processInfo.arguments.contains("--demo") {
                let args = ProcessInfo.processInfo.arguments
                let state = args.firstIndex(of: "--state").flatMap { $0 + 1 < args.count ? HomeStatus(rawValue: args[$0 + 1]) : nil } ?? .ready
                home.startDemo(state: state)
            } else if !ProcessInfo.processInfo.arguments.contains("--fresh") {
                let mode = UserDefaults.standard.string(forKey: "homeMode")
                if mode == "demo" { home.startDemo() } else if mode == "live" { home.connect() }
            }
            UIApplication.shared.isIdleTimerDisabled = (keepAwake || standby.enabled) && phase == .active
            weather.setDemo(home.demo)
            if ProcessInfo.processInfo.arguments.contains("--far") { page = .clock }
        }
        .task(id: phase == .active && !standby.dimmed && (page == .home || page == .overview || page == .photos) && panel == nil && photos.slideshow) {
            guard phase == .active, !standby.dimmed, page == .home || page == .overview || page == .photos, panel == nil, photos.slideshow else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                photos.next()
            }
        }
        .task(id: "\(phase == .active && !standby.dimmed)-\(home.demo)-\(page == .overview || panel == .weather)-\(weather.city?.latitude ?? 0)-\(weather.city?.longitude ?? 0)-\(weather.followsLocation)-\(weather.provider.rawValue)") {
            guard phase == .active, !standby.dimmed, !home.demo, page == .overview || panel == .weather else { return }
            while !Task.isCancelled {
                weatherLocation.update(weather)
                await weather.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .task(id: "\(phase == .active)-\(panel == nil && page != .settings && !audio.playing && sceneToRun == nil && home.error == nil)-\(home.demo)") {
            standby.environment(active: phase == .active,
                                available: panel == nil && page != .settings && !audio.playing && sceneToRun == nil && home.error == nil, demo: home.demo)
            guard phase == .active else { return }
            while !Task.isCancelled {
                standby.tick()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
        .onChange(of: keepAwake) { _, _ in updateIdleTimer() }
        .onChange(of: standby.enabled) { _, _ in updateIdleTimer() }
        .onChange(of: standby.dimmed) { _, value in if value { navigationVisible = false; weatherLocation.stop() } }
        .onDisappear { standby.environment(active: false, available: false, demo: home.demo); UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: phase) { _, value in
            UIApplication.shared.isIdleTimerDisabled = (keepAwake || standby.enabled) && value == .active
            photos.setActive(value == .active)
            if value == .active {
                home.refresh()
                if showPersonal && !home.demo { Task { await personal.loadCalendar(); await personal.loadReminders() } }
            } else { standby.environment(active: false, available: false, demo: home.demo); weatherLocation.stop(); personal.clear(); audio.player.pause(); navigationVisible = false }
        }
        .onChange(of: home.status) { _, value in
            if !home.demo && value != .ready && panel == .camera { panel = nil; selectedCamera = nil }
        }
        .onChange(of: home.homeName) { _, _ in selectedRoom = "All rooms"; widgetOffsets = Array(repeating: 0, count: 6) }
        .onChange(of: home.selectedHomeID) { _, _ in
            selectedRoom = "All rooms"; widgetOffsets = Array(repeating: 0, count: 6); selectedAccessoryID = nil; sceneToRun = nil
            if panel == .accessory || panel == .camera { panel = nil; selectedCamera = nil }
        }
        .onChange(of: home.demo) { _, value in weather.setDemo(value); if value { weatherLocation.stop() }; selectedRoom = "All rooms"; widgetOffsets = Array(repeating: 0, count: 6); personal.clear(); audio.stop() }
    }
    private func updateIdleTimer() { UIApplication.shared.isIdleTimerDisabled = (keepAwake || standby.enabled) && phase == .active }
    private var standbySurface: some View {
        ZStack {
            Color.clear.ignoresSafeArea().contentShape(Rectangle()).onTapGesture { standby.wake() }
                .accessibilityElement().accessibilityLabel("Standby. Tap to restore brightness")
                .accessibilityAddTraits(.isButton).accessibilityAction { standby.wake() }.accessibilityIdentifier("standbySurface")
            if home.demo {
                VStack(spacing: 16) {
                    Text("DEMO · Standby").font(.headline).accessibilityIdentifier("demoBadge")
                    Text(standby.message).font(.footnote).accessibilityIdentifier("standbyDemoStatus")
                    Button("Simulate sound") { standby.soundDetected() }.accessibilityIdentifier("standbyDemoSound")
                    if standby.checking {
                        Button("Simulate face nearby") { standby.simulateFace(true) }.accessibilityIdentifier("standbyDemoFace")
                        Button("Simulate no face") { standby.simulateFace(false) }.accessibilityIdentifier("standbyDemoNoFace")
                    }
                    Button("Wake display") { standby.wake() }.accessibilityIdentifier("standbyDemoWake")
                }.foregroundStyle(.white).padding().background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack {
                    Spacer()
                    Text(standby.message).font(.footnote).padding(10)
                        .background(.black.opacity(0.7), in: Capsule())
                        .accessibilityIdentifier("standbySensorStatus")
                        .allowsHitTesting(false)
                    if standby.mode == .soundAndDepth {
                        Text(standby.lastDetection).font(.caption).multilineTextAlignment(.center)
                            .accessibilityIdentifier("standbyDetectionResult")
                    }
                    if standby.showSoundLevels, let level = standby.soundLevel {
                        Text(String(format: "Input %.0f dBFS · trigger %.0f dBFS", level, standby.soundThreshold))
                            .font(.caption.monospacedDigit()).accessibilityIdentifier("standbyAudioLevels")
                    }
                }.padding(24).allowsHitTesting(false)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func activate(_ tile: HomeTile) {
        standby.activity()
        if tile.kind == .power { home.toggle(tile) }
        else if tile.writable { selectedAccessoryID = tile.id; panel = .accessory }
    }
    private var visibleTiles: [HomeTile] { home.tiles.filter { selectedRoom == "All rooms" || $0.room == selectedRoom } }
    private var navigationAnimation: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.46, bounce: 0.06) }
    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: pageForward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: pageForward ? .leading : .trailing).combined(with: .opacity))
    }
    private func toggleNavigation() { standby.activity(); withAnimation(navigationAnimation) { navigationVisible.toggle() } }
    private func selectPage(_ destination: DashboardPage) {
        standby.activity()
        pageForward = destination.rawValue >= page.rawValue
        withAnimation(navigationAnimation) { page = destination; navigationVisible = false }
    }
    private func movePage(forward: Bool) { selectPage(page.adjacent(forward: forward)) }
    @ViewBuilder private func pageContent(side: CGFloat) -> some View {
        switch page {
        case .home:
            if home.status == .ready {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(0..<6) { slot in widgetSlot(slot, size: side - 24) }
                        }.padding(12)
                    }
                } else { glassBoard(side: side) }
            } else {
                ScrollView {
                    VStack {
                        if home.demo { demoMark }
                        if home.status == .welcome { welcome } else { stateCard }
                    }.padding(20)
                }
            }
        case .overview:
            OverviewBoard(photos: photos, weather: weather, demoDate: home.demo ? demoDate : nil, side: side, chooseAlbum: { panel = .photos }, configureWeather: { panel = .weather })
        case .clock:
            AnalogHomeClock(date: home.demo ? demoDate : nil, numbered: false)
                .padding(side * 0.07).frame(width: side, height: side)
                .modifier(GlassSurface(radius: side * 0.1))
                .accessibilityIdentifier("fullClock")
                .overlay(alignment: .topLeading) { if home.demo { demoMark.padding(20) } }
        case .photos: EmptyView() // Full-screen composition lives outside the square widget board.
        case .settings:
            NavigationStack {
                settings.foregroundStyle(ink).background(.regularMaterial)
                    .toolbar(.hidden, for: .navigationBar)
            }.clipShape(RoundedRectangle(cornerRadius: side * 0.035))
                .overlay(alignment: .topTrailing) { if home.demo { demoMark.foregroundStyle(ink).padding(12).allowsHitTesting(false) } }
        }
    }
    private var demoMark: some View {
        Text("DEMO").font(.system(size: 11, weight: .semibold)).tracking(1)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.12), in: Capsule())
            .accessibilityIdentifier("demoBadge")
    }
    private func tabButton(_ destination: DashboardPage, horizontal: Bool) -> some View {
        Button { selectPage(destination) } label: {
            Group {
                if horizontal {
                    VStack(spacing: 5) {
                        Image(systemName: destination.symbol).font(.system(size: 20, weight: .medium))
                        Text(destination.title).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    Label(destination.title, systemImage: destination.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 12)
                }
            }.background(page == destination ? .white.opacity(0.24) : .clear, in: RoundedRectangle(cornerRadius: 15))
        }.accessibilityIdentifier("tab-\(destination.rawValue)")
            .accessibilityAddTraits(page == destination ? .isSelected : [])
    }
    private var navigationRail: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(DashboardPage.allCases, id: \.self) { tabButton($0, horizontal: false) }
                Divider().overlay(.white.opacity(0.25))
                navigationActions(horizontal: false)
            }.padding(8)
        }.frame(maxHeight: 650).modifier(GlassSurface(radius: 24))
            .buttonStyle(.plain).accessibilityElement(children: .contain).accessibilityIdentifier("sideNavigation")
    }
    private var bottomNavigation: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(DashboardPage.allCases, id: \.self) { tabButton($0, horizontal: true) }
            }
            Divider().overlay(.white.opacity(0.25))
            HStack(spacing: 5) { navigationActions(horizontal: true) }
        }.padding(9).modifier(GlassSurface(radius: 28))
            .buttonStyle(.plain).accessibilityElement(children: .contain).accessibilityIdentifier("bottomNavigation")
    }
    @ViewBuilder private func navigationActions(horizontal: Bool) -> some View {
        navigationAction("Today", "calendar", id: "agendaCard", horizontal: horizontal) { panel = .agenda }
        navigationAction("Camera", "video", id: "cameraCard", horizontal: horizontal) { selectedCamera = home.cameras.first; panel = .camera }
        navigationAction("Controls", "switch.2", id: "allControls", horizontal: horizontal) { panel = .controls }
        navigationAction("Music", "music.note", id: "musicCard", horizontal: horizontal) { panel = .music }
        navigationAction("Albums", "photo.stack", id: "wallAlbums", horizontal: horizontal) { panel = .photos }
        navigationAction("Hide", horizontal ? "chevron.down" : "chevron.right", id: "hideNavigation", horizontal: horizontal) {}
    }
    private func navigationAction(_ title: String, _ symbol: String, id: String, horizontal: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(navigationAnimation) { navigationVisible = false }
        } label: {
            Group {
                if horizontal { Image(systemName: symbol).font(.system(size: 19)).frame(maxWidth: .infinity, minHeight: 44) }
                else { Label(title, systemImage: symbol).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 12) }
            }.contentShape(Rectangle())
        }.accessibilityLabel(title).accessibilityIdentifier(id)
    }
    private var roomChoices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(["All rooms"] + Array(Set(home.tiles.map(\.room))).sorted(), id: \.self) { room in
                    Button {
                        withAnimation(navigationAnimation) { selectedRoom = room; widgetOffsets = Array(repeating: 0, count: 6) }
                    } label: {
                        Text(room).padding(.horizontal, 16).padding(.vertical, 12)
                            .background(selectedRoom == room ? Color.purple.opacity(0.15) : Color.gray.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain).accessibilityIdentifier("room-\(room)")
                        .accessibilityAddTraits(selectedRoom == room ? .isSelected : [])
                }
            }
        }
    }
    private func glassBoard(side: CGFloat) -> some View {
        let gap = side * 0.018
        let cell = (side - gap * 2) / 3
        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                widgetSlot(0, size: cell * 2 + gap)
                VStack(spacing: gap) {
                    widgetSlot(1, size: cell)
                    widgetSlot(2, size: cell)
                }
            }
            HStack(spacing: gap) {
                widgetSlot(3, size: cell)
                widgetSlot(4, size: cell)
                widgetSlot(5, size: cell)
            }
        }.buttonStyle(.plain).frame(width: side, height: side)
    }
    private func options(for slot: Int) -> [DashboardWidget] {
        DashboardWidget.options(for: slot, tiles: visibleTiles, scenes: home.scenes)
    }
    private func widgetSlot(_ slot: Int, size: CGFloat) -> some View {
        WidgetCarousel(items: options(for: slot), selection: $widgetOffsets[slot], size: size,
                       radius: size * (slot == 0 ? 0.09 : 0.19), slot: slot,
                       showNavigation: { standby.activity(); withAnimation(navigationAnimation) { navigationVisible = true } }) { widget in
            widgetContent(widget, size: size)
        }.onChange(of: widgetOffsets[slot]) { _, _ in standby.activity() }
            .overlay(alignment: .topLeading) { if slot == 0 && home.demo { demoMark.padding(size * 0.035).allowsHitTesting(false) } }
    }
    @ViewBuilder private func widgetContent(_ widget: DashboardWidget, size: CGFloat) -> some View {
        switch widget {
        case .climate(let id):
            if let tile = visibleTiles.first(where: { $0.id == id }) { climateTile(tile, size: size) }
        case .clock:
            AnalogHomeClock(date: home.demo ? demoDate : nil, numbered: false)
                .padding(size * 0.05).frame(width: size, height: size)
                .modifier(GlassSurface(radius: size * 0.5))
                .accessibilityIdentifier("clockWidget")
        case .photo:
            Button { panel = .photos } label: {
                ZStack {
                    FadingPhoto(frame: photos.frame)
                    if photos.image == nil {
                        Color.clear
                        Image(systemName: photos.message == nil ? "photo" : "photo.badge.exclamationmark").font(.system(size: size * 0.25, weight: .ultraLight)).opacity(0.9)
                    }
                }.frame(width: size, height: size).clipped().clipShape(RoundedRectangle(cornerRadius: size * 0.19))
                    .modifier(GlassSurface(radius: size * 0.19))
            }.accessibilityLabel("Photos, \(photos.albumTitle)").accessibilityIdentifier("photoWidget")
                .accessibilityAction(named: "Next photo") { photos.next() }
        case .scene(let name):
            Button { sceneToRun = name } label: {
                boardTile("sun.max.fill", name, home.notice?.contains(name) == true ? "Done" : "Scene", size: size)
            }.disabled(home.sceneBusy).accessibilityIdentifier("scene-\(name)")
        case .accessory(let id):
            if let tile = visibleTiles.first(where: { $0.id == id }) {
                Button { activate(tile) } label: {
                    boardTile(tile.symbol, tile.name, "\(tile.room) · \(tile.value)", size: size, active: tile.isOn)
                        .overlay(alignment: .topTrailing) { if home.busy.contains(id) { ProgressView().padding(16) } }
                }.disabled(!tile.writable || !tile.reachable || home.busy.contains(id))
                    .accessibilityLabel("\(tile.name), \(tile.room), \(tile.value)").accessibilityIdentifier("accessory-\(tile.name)")
            }
        case .camera:
            Button { selectedCamera = home.cameras.first; panel = .camera } label: {
                boardTile("video.fill", "Camera", home.demo ? "Demo · no live feed" : (home.cameras.first?.name ?? "No camera"), size: size)
            }.accessibilityIdentifier("cameraWidget")
        case .agenda:
            Button { panel = .agenda } label: { boardTile("calendar", "Today", "Calendar", size: size) }.accessibilityIdentifier("agendaWidget")
        case .empty(let slot):
            let title = slot == 0 ? "Climate" : slot == 3 ? "Scenes" : slot == 5 ? "Lights" : "Devices"
            boardTile(slot == 0 ? "thermometer.medium" : slot == 3 ? "sun.max.fill" : slot == 5 ? "lightbulb.fill" : "switch.2",
                      title, "None in this room", size: size)

        }
    }
    private func climateTile(_ tile: HomeTile, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Reserve the complete font line box and side bearings before scaling.
            Text(tile.number.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: size * 0.40, weight: .regular))
                .lineLimit(1).minimumScaleFactor(0.35)
                .frame(width: size * 0.82, height: size * 0.61)
                .padding(.top, size * 0.08)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: tile.number)
                .accessibilityIdentifier("temperatureValue")
            Spacer(minLength: 0)
            HStack(spacing: size * 0.015) {
                temperatureArrow(tile, increase: false, size: size)
                VStack(spacing: size * 0.008) {
                    Text(tile.kind == .targetTemperature ? "Thermostat" : tile.name)
                        .font(widgetFont(size * 0.051, weight: .semibold))
                    Text("\(tile.room) · \(tile.value)")
                        .font(widgetFont(size * 0.05)).opacity(0.88)
                }.lineLimit(2).minimumScaleFactor(0.65).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                temperatureArrow(tile, increase: true, size: size)
            }.padding(.horizontal, size * 0.06).padding(.bottom, size * 0.07)
        }.frame(width: size, height: size).modifier(GlassSurface(radius: size * 0.09))
            .accessibilityElement(children: .contain).accessibilityIdentifier("climateWidget")
    }
    private func temperatureArrow(_ tile: HomeTile, increase: Bool, size: CGFloat) -> some View {
        let next = tile.temperatureStep(increase: increase)
        return Button {
            standby.activity()
            if let next { home.adjust(tile.id, to: next) }
        } label: {
            Image(systemName: increase ? "chevron.up" : "chevron.down")
                .font(.system(size: size * 0.065, weight: .semibold))
                .frame(width: max(44, size * 0.15), height: max(44, size * 0.15))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .disabled(next == nil || home.busy.contains(tile.id))
            .opacity(next == nil || home.busy.contains(tile.id) ? 0.3 : 1)
            .accessibilityLabel(increase ? "Increase temperature" : "Decrease temperature")
            .accessibilityValue(tile.value)
            .accessibilityHint(tile.kind == .targetTemperature ? "Adjust target temperature" : "Read-only sensor")
            .accessibilityIdentifier(increase ? "temperatureUp" : "temperatureDown")
    }
    private func widgetFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        dynamicTypeSize.isAccessibilitySize ? .system(.title2, weight: weight) : .system(size: size, weight: weight)
    }
    private func boardTile(_ symbol: String, _ title: String, _ subtitle: String, size: CGFloat, active: Bool = false) -> some View {
        VStack(spacing: size * 0.025) {
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.system(size: size * 0.28, weight: .regular)).frame(height: size * 0.33)
            Spacer(minLength: 0)
            Text(title).font(widgetFont(size * 0.102, weight: .medium)).lineLimit(2)
            Text(subtitle).font(widgetFont(size * 0.102)).opacity(0.85).lineLimit(2)
        }.multilineTextAlignment(.center).padding(.horizontal, size * 0.06).padding(.top, size * 0.14).padding(.bottom, size * 0.14)
            .frame(width: size, height: size).modifier(GlassSurface(radius: size * 0.19, active: active))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: active)
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "house.and.flag.fill").font(.system(size: 72)).foregroundStyle(Color.purple.opacity(0.6))
            Text(HomeStatus.welcome.title).font(.system(size: 42, weight: .medium, design: .rounded))
            Text(HomeStatus.welcome.detail).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Connect Apple Home") { home.connect() }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("connectHome")
            Button("Explore demo") { home.startDemo() }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("exploreDemo")
            Text("HomeViewPad is a foreground iPad dashboard. Your HomePod mini remains your home hub and Siri speaker.").font(.callout).foregroundStyle(.secondary)
        }.padding(32).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 32)).foregroundStyle(ink)
    }
    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: home.status == .denied ? "hand.raised.fill" : "house.circle").font(.largeTitle)
            Text(home.status.title).font(.largeTitle.bold()).accessibilityIdentifier("homeStateTitle")
            Text(home.status.detail).font(.title3)
            if home.status == .loading { ProgressView() }
            Button("Retry connection") { home.demo ? home.startDemo() : home.connect() }.buttonStyle(.borderedProminent)
            Button("Explore demo") { home.startDemo() }.buttonStyle(.bordered)
            if home.status == .denied { Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } }
        }.padding(32).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 30)).foregroundStyle(ink)
    }
    @ViewBuilder private func panelContent(_ selected: Panel) -> some View {
        switch selected {
        case .camera:
            VStack { if home.cameras.count > 1 { Picker("Camera", selection: $selectedCamera) { ForEach(home.cameras, id: \.uniqueIdentifier) { Text($0.name).tag(Optional($0)) } }.padding() }; CameraSheet(accessory: selectedCamera, demo: home.demo).id(selectedCamera?.uniqueIdentifier) }
        case .photos: PhotosPanel(photos: photos)
        case .weather: WeatherPanel(weather: weather, location: weatherLocation)
        case .standby: StandbySettings(standby: standby) {
            self.panel = nil; selectPage(.overview)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                standby.dim()
            }
        }
        case .accessory:
            if let id = selectedAccessoryID { AccessoryAdjustmentView(home: home, id: id) }
        case .settings: settings
        case .controls:
            List {
                if !home.demo {
                    Section(home.homeName) {
                        Text("Live Apple Home · \(home.tiles.count) supported values")
                        Button("Refresh home status") { home.refresh() }
                        if let error = home.error { Text(error).foregroundStyle(.red) }
                    }
                }
                Section("Rooms") { roomChoices }
                Section("Accessories") {
                    ForEach(visibleTiles) { tile in
                        Button { activate(tile) } label: { Label("\(tile.name) · \(tile.value)", systemImage: tile.symbol) }
                            .disabled(!tile.writable || !tile.reachable || home.busy.contains(tile.id))
                            .accessibilityIdentifier("accessory-\(tile.name)")
                    }
                }
                Section("Scenes") {
                    ForEach(home.scenes, id: \.self) { scene in Button(scene) { sceneToRun = scene }.disabled(home.sceneBusy).accessibilityIdentifier("scene-\(scene)") }
                    if let notice = home.notice { Text(notice).accessibilityIdentifier("sceneNotice") }
                }
            }.foregroundStyle(ink)
        case .agenda: agenda
        case .music:
            VStack(spacing: 28) {
                Image(systemName: "hifispeaker.fill").font(.system(size: 80)).foregroundStyle(Color.purple)
                Text(audio.title).font(.title).multilineTextAlignment(.center)
                Text(audio.message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Choose audio file") { importAudio = true }.buttonStyle(.borderedProminent)
                HStack(spacing: 32) {
                    Button(audio.playing ? "Pause" : "Play") { audio.toggle() }.disabled(audio.player.currentItem == nil).buttonStyle(.bordered)
                    AirPlayPicker().frame(width: 60, height: 60)
                }
                Text("Plays files you select. Apple Music catalog, HomePod playback history and Siri are not accessible here. You can also use Music and Control Center for AirPlay.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(36)
            .fileImporter(isPresented: $importAudio, allowedContentTypes: [.audio]) { result in
                switch result { case .success(let url): audio.load(url); case .failure(let error): audio.message = error.localizedDescription }
            }

        }
    }
    private var settings: some View {
        Form {
            Section("Home connection") {
                Text(home.demo ? "Demo mode — sample data only" : "Apple Home · \(home.status.rawValue)")
                if !home.demo && !home.homes.isEmpty {
                    ForEach(home.homes, id: \.uniqueIdentifier) { item in
                        Button { home.select(item) } label: {
                            HStack { Text(item.name); Spacer(); if home.selectedHomeID == item.uniqueIdentifier { Image(systemName: "checkmark") } }
                        }
                    }
                    Text("\(home.tiles.count) supported values · \(home.scenes.count) scenes").font(.footnote)
                }
                Button("Connect Apple Home") { home.connect(); panel = nil; selectPage(.home) }
                Button("Explore demo") { home.startDemo(); panel = nil; selectPage(.home) }
                Button("Disconnect home", role: .destructive) { home.disconnect(); panel = nil; selectPage(.home) }
            }
            Section("Display") {
                Toggle("Teal background", isOn: $tealWallpaper).accessibilityIdentifier("tealWallpaper")
                Text("Tap the background to show navigation: below in portrait, on the right in landscape. Position dots show the current widget. Swipe left or right to change pages. Swipe up or down inside a widget to change it. VoiceOver offers the same actions.").font(.footnote)
                Toggle("Keep display awake in foreground", isOn: $keepAwake).accessibilityIdentifier("keepAwake")
                Text("Does not replace the lock screen or reopen the app after reboot. Use Guided Access in iPad Settings if appropriate. Optional standby keeps the app awake and dims it; configure sound and short TrueDepth wake checks separately.").font(.footnote)
                Button("Standby and wake") { panel = .standby }.accessibilityIdentifier("standbySettings")
                Button("Weather city and units") { panel = .weather }.accessibilityIdentifier("weatherSettings")
                Button("Photo widget and albums") { panel = .photos }.accessibilityIdentifier("photoSettings")
            }
            Section("Personal content") {
                Toggle("Show calendar and reminders on this shared screen", isOn: $showPersonal)
                Text("Anyone looking at this iPad can see enabled personal content. HomeViewPad does not identify household members. Disable to hide; revoke permissions in Settings.").font(.footnote)
            }
            Section("HomePod mini") {
                Text("Add HomePod mini to the same home in Apple's Home app. It provides supported home hub, Thread and Siri functions independently. Choose it through AirPlay for audio. HomeViewPad cannot access its microphone, host Siri, or send Intercom messages.")
            }
            if home.demo {
                Section("Demo diagnostics") {
                    ForEach([HomeStatus.ready, .loading, .denied, .empty, .offline], id: \.self) { state in Button("Simulate \(state.rawValue)") { home.startDemo(state: state); panel = nil; selectPage(.home) } }
                }
            }
            Section("About") { Text("HomeViewPad · Independent open-source iPad dashboard\nNo analytics. No accounts. No server.\nNot affiliated with Apple.") }
        }.onChange(of: showPersonal) { _, value in if !value { personal.clear() } }
    }
    private var agenda: some View {
        List {
            if home.demo {
                Section("DEMO · Sample day") { Label("17:30 · Water the plants", systemImage: "leaf"); Label("Pick up fresh bread", systemImage: "checklist") }
            } else if !showPersonal {
                Section { Text("Personal content is hidden on this shared screen."); Button("Enable in Settings") { panel = .settings } }
            } else {
                Section("Calendar · \(personal.calendarStatus)") {
                    ForEach(Array(personal.events.enumerated()), id: \.offset) { Text($0.element) }
                    Button("Connect / refresh calendar") { Task { await personal.loadCalendar(request: true) } }
                }
                Section("Reminders · \(personal.reminderStatus)") {
                    ForEach(Array(personal.reminders.enumerated()), id: \.offset) { Label($0.element, systemImage: "circle") }
                    Button("Connect / refresh reminders") { Task { await personal.loadReminders(request: true) } }
                }
            }
        }.task { if showPersonal && !home.demo { await personal.loadCalendar(); await personal.loadReminders() } }
    }
}

/// Original vector clock drawn with system typography; no promotional assets.
struct AnalogHomeClock: View {
    var date: Date?
    var numbered = true
    var monochrome = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Canvas { graphics, size in
                let d = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = d * 0.47
                let accent = monochrome ? Color(red: 1, green: 0.77, blue: 0.16) : Color(red: 0.50, green: 0.46, blue: 0.66)
                for tick in 0..<60 {
                    if !numbered && tick % 5 != 0 { continue }
                    let angle = Double(tick) * .pi / 30 - .pi / 2
                    let outer = radius
                    let inner = radius - (tick % 5 == 0 ? (numbered ? d * 0.038 : d * 0.075) : d * 0.017)
                    var path = Path(); path.move(to: CGPoint(x: center.x + cos(angle)*inner, y: center.y + sin(angle)*inner)); path.addLine(to: CGPoint(x: center.x + cos(angle)*outer, y: center.y + sin(angle)*outer))
                    graphics.stroke(path, with: .color(monochrome ? .white.opacity(tick % 5 == 0 ? 0.95 : 0.5) : numbered ? accent.opacity(0.6) : .white), style: StrokeStyle(lineWidth: tick % 5 == 0 ? d * 0.009 : d * 0.004, lineCap: .round))
                }
                if numbered { for n in 1...12 {
                    let a = Double(n) * .pi / 6 - .pi / 2
                    graphics.draw(Text(String(n)).font(.system(size: d * 0.075, weight: .medium)).foregroundColor(monochrome ? .white : accent), at: CGPoint(x: center.x + cos(a)*d*0.365, y: center.y + sin(a)*d*0.365))
                } }
                let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date ?? context.date)
                let minute = date == nil ? Double(components.minute ?? 0) : 9, second = date == nil ? Double(components.second ?? 0) : 30
                let hour = (date == nil ? Double((components.hour ?? 0) % 12) : 10) + minute / 60
                for (angle, length, thickness, color) in [(hour * .pi/6, d*0.25, d*0.018, numbered && !monochrome ? Color.black : .white), (minute * .pi/30, d*0.39, d*0.014, numbered && !monochrome ? Color.black : .white), (second * .pi/30, d*0.42, d*0.006, numbered ? accent : .white.opacity(0.65))] {
                    var hand = Path(); hand.move(to: CGPoint(x: center.x - sin(angle)*d*0.045, y: center.y + cos(angle)*d*0.045)); hand.addLine(to: CGPoint(x: center.x + sin(angle)*length, y: center.y - cos(angle)*length))
                    graphics.stroke(hand, with: .color(color), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                }
                graphics.fill(Path(ellipseIn: CGRect(x: center.x-d*0.018, y: center.y-d*0.018, width: d*0.036, height: d*0.036)), with: .color(numbered ? accent : .white))
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Analog clock").accessibilityValue(date == nil ? Date.now.formatted(date: .omitted, time: .shortened) : "10:09 demo time")
    }
}

/// Original, resolution-independent wallpaper shared behind every translucent widget.
private struct AmbientWallpaper: View {
    let teal: Bool
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack {
                LinearGradient(colors: teal
                    ? [Color(red: 0.12, green: 0.40, blue: 0.38), Color(red: 0.05, green: 0.23, blue: 0.23)]
                    : [Color(red: 0.65, green: 0.62, blue: 0.57), Color(red: 0.36, green: 0.34, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.65, height: h * 1.5).rotationEffect(.degrees(-28)).offset(x: -w * 0.22, y: -h * 0.22).blur(radius: 18)
                Ellipse().fill(.black.opacity(0.18)).frame(width: w * 0.75, height: h * 0.55)
                    .rotationEffect(.degrees(-35)).offset(x: w * 0.3, y: h * 0.28).blur(radius: 32)
                Ellipse().stroke(.white.opacity(0.13), lineWidth: w * 0.07).frame(width: w, height: h * 0.8)
                    .rotationEffect(.degrees(-30)).offset(x: w * 0.3, y: -h * 0.22).blur(radius: 24)
            }.frame(width: w, height: h).clipped()
        }.accessibilityHidden(true)
    }
}

private struct GlassSurface: ViewModifier {
    let radius: CGFloat
    var enabled = true
    var active = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if enabled {
            content.background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    if reduceTransparency { shape.fill(Color(white: 0.32)) }
                    else {
                        shape.fill(.ultraThinMaterial).environment(\.colorScheme, .light).opacity(0.42)
                        shape.fill(LinearGradient(colors: [.white.opacity(active ? 0.23 : 0.15), .white.opacity(0.015), .white.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .overlay(shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.85), location: 0), .init(color: .white.opacity(0.22), location: 0.4), .init(color: .white.opacity(0.12), location: 0.6), .init(color: .white.opacity(0.6), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
                .overlay(shape.inset(by: 2).strokeBorder(.white.opacity(0.08), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
            }
        } else { content }
    }
}


/// Present confirmations in the same presentation context as the tapped scene.
private struct SceneConfirmation: ViewModifier {
    @Binding var name: String?
    let enabled: Bool
    let run: (String) -> Void
    func body(content: Content) -> some View {
        content.alert("Run \(name ?? "scene")?", isPresented: Binding(
            get: { enabled && name != nil },
            set: { if enabled && !$0 { name = nil } }
        )) {
            if let selected = name { Button("Run scene") { run(selected); name = nil } }
            Button("Cancel", role: .cancel) { name = nil }
        } message: {
            Text("Scenes can change multiple accessories, including locks or doors. Review the scene in Apple Home before running it.")
        }
    }
}
