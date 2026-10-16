import SwiftUI
import AVFoundation

/// Foreground dimming only. This never locks, unlocks, or launches the device.
enum StandbyWakeMode: String, CaseIterable {
    case sound, soundAndDepth
    var title: String { self == .sound ? "Sound" : "Sound + TrueDepth face check" }
}

enum StandbySoundSensitivity: String, CaseIterable {
    case low, standard, high
    var title: String { rawValue.capitalized }
    var minimum: Float { switch self { case .low: -40; case .standard: -55; case .high: -65 } }
    var margin: Float { switch self { case .low: 17; case .standard: 8; case .high: 6 } }
}

@MainActor protocol StandbySensing: AnyObject {
    var hasTrueDepth: Bool { get }
    var microphoneAllowed: Bool { get }
    var cameraAllowed: Bool { get }
    func requestPermissions(depth: Bool) async
    func listen(level: @escaping (Float) -> Void, failure: @escaping (String) -> Void) throws
    func checkFace(completion: @escaping (Bool) -> Void)
    func stop()
}

/// Sustained sound or one distinct transient above the calibrated room floor.
struct StandbySoundGate {
    var sensitivity: StandbySoundSensitivity = .standard
    private(set) var floor: Float = -60
    var threshold: Float { max(sensitivity.minimum, floor + sensitivity.margin) }
    private var samples = 0
    private var peaks = 0
    private var armed = true
    mutating func consume(_ db: Float) -> Bool {
        guard db.isFinite else { return false }
        if samples < 12 { floor = samples == 0 ? db : floor * 0.8 + db * 0.2; samples += 1; return false }
        if db > threshold {
            peaks += 1
            if (peaks >= 2 || db >= threshold + 8) && armed { armed = false; peaks = 0; return true }
        } else {
            peaks = 0; armed = true; floor = floor * 0.98 + db * 0.02
        }
        return false
    }
}

@MainActor final class StandbyStore: ObservableObject {
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "standbyEnabled"); sensorFailure = nil; wake() } }
    @Published var mode: StandbyWakeMode { didSet { defaults.set(mode.rawValue, forKey: "standbyWakeMode"); sensorFailure = nil; wake() } }
    @Published var delay: Double { didSet { defaults.set(delay, forKey: "standbyDelay"); wake() } }
    @Published var sensitivity: StandbySoundSensitivity { didSet { defaults.set(sensitivity.rawValue, forKey: "standbySoundSensitivity"); wake() } }
    @Published var showSoundLevels = false
    @Published private(set) var soundLevel: Float?
    @Published private(set) var soundThreshold: Float = -55
    @Published private(set) var lastDetection = "No sound detected yet."
    @Published private(set) var dimmed = false
    @Published private(set) var checking = false
    @Published private(set) var message = "Off. Your camera and microphone are not used."
    @Published private(set) var requesting = false
    @Published private(set) var demo = false
    @Published private(set) var sensorFailure: String?
    @Published private(set) var receivingAudio = false
    private let defaults: UserDefaults
    private let sensors: any StandbySensing
    private let now: () -> Date
    private let readBrightness: @MainActor () -> CGFloat
    private let writeBrightness: @MainActor (CGFloat) -> Void
    private var previousBrightness: CGFloat?
    private var lastActivity: Date
    private var lastCheck: Date = .distantPast
    private var active = false
    private var available = false
    private var generation = UUID()
    private var gate = StandbySoundGate()
    private var deadline: Task<Void, Never>?
    private var audioDeadline: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, sensors: (any StandbySensing)? = nil,
         now: @escaping () -> Date = Date.init,
         readBrightness: @escaping @MainActor () -> CGFloat = { UIScreen.main.brightness },
         writeBrightness: @escaping @MainActor (CGFloat) -> Void = { UIScreen.main.brightness = $0 }) {
        self.defaults = defaults; self.sensors = sensors ?? StandbySensors(); self.now = now
        self.readBrightness = readBrightness; self.writeBrightness = writeBrightness
        enabled = defaults.bool(forKey: "standbyEnabled")
        mode = StandbyWakeMode(rawValue: defaults.string(forKey: "standbyWakeMode") ?? "") ?? .sound
        sensitivity = StandbySoundSensitivity(rawValue: defaults.string(forKey: "standbySoundSensitivity") ?? "") ?? .standard
        let saved = defaults.double(forKey: "standbyDelay")
        delay = [30.0, 60, 120, 300].contains(saved) ? saved : 60
        lastActivity = now()
    }
    var hasTrueDepth: Bool { sensors.hasTrueDepth }
    var permitted: Bool { demo || (sensors.microphoneAllowed && (mode == .sound || (hasTrueDepth && sensors.cameraAllowed))) }
    var setupIssue: String? {
        guard !demo else { return nil }
        if let sensorFailure { return sensorFailure }
        if !sensors.microphoneAllowed { return "Microphone access is required. Allow access in Standby settings." }
        if mode == .soundAndDepth {
            if !hasTrueDepth { return "TrueDepth is unavailable. Choose Sound in Standby settings." }
            if !sensors.cameraAllowed { return "Camera access is required for TrueDepth. Allow access or choose Sound." }
        }
        return nil
    }
    var canDim: Bool { enabled && active && available && !requesting && setupIssue == nil }
    func environment(active: Bool, available: Bool, demo: Bool) {
        guard self.active != active || self.available != available || self.demo != demo else { return }
        self.active = active; self.available = available; self.demo = demo
        wake()
    }
    func requestPermissions() async {
        guard !demo, !requesting else { return }
        requesting = true
        await sensors.requestPermissions(depth: mode == .soundAndDepth)
        requesting = false
        sensorFailure = nil
        wake()
    }
    func activity() { if dimmed { wake() } else { lastActivity = now() } }
    func tick() { if canDim && !dimmed && now().timeIntervalSince(lastActivity) >= delay { dim() } }
    func dim() {
        guard canDim, !dimmed else { return }
        previousBrightness = readBrightness(); dimmed = true; writeBrightness(0)
        gate = StandbySoundGate(sensitivity: sensitivity); lastCheck = .distantPast; soundLevel = nil
        lastDetection = "No sound detected in this standby session."
        message = demo ? "DEMO · Simulated standby. No sensors are running." : "Tap to wake."
        guard !demo else { return }
        startListening()
    }
    private func startListening() {
        let id = generation
        receivingAudio = false
        do {
            try sensors.listen(level: { [weak self] db in
                guard let self, self.generation == id, self.dimmed, !self.checking, !self.demo else { return }
                guard db.isFinite else { return }
                if !self.receivingAudio {
                    self.receivingAudio = true
                    self.audioDeadline?.cancel(); self.audioDeadline = nil
                    self.message = self.mode == .sound ? "Microphone active · sound wakes display" : "Microphone active · sound starts TrueDepth"
                }
                let triggered = self.gate.consume(db)
                if self.showSoundLevels { self.soundLevel = db; self.soundThreshold = self.gate.threshold }
                if triggered { self.soundDetected() }
            }, failure: { [weak self] message in
                guard let self, self.generation == id else { return }
                self.sensingFailed(message)
            })
            guard generation == id, dimmed else { return }
            message = "Starting microphone…"
            audioDeadline = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                guard let self, self.generation == id, self.dimmed, !self.receivingAudio else { return }
                self.sensingFailed("No microphone input received. Check audio access and retry in Standby settings.")
            }
        } catch { sensingFailed("Microphone could not start: \(error.localizedDescription)") }
    }
    private func sensingFailed(_ reason: String) {
        sensorFailure = reason
        wake() // Never leave the user dimmed with non-working automatic wake.
    }
    func soundDetected() {
        guard canDim, dimmed, !checking, now().timeIntervalSince(lastCheck) >= 15 else { return }
        if mode == .sound { lastDetection = demo ? "DEMO · Simulated sound wake." : "Sound detected · display awakened."; wake(); return }
        lastDetection = demo ? "DEMO · Simulated face check." : "Sound detected · checking for a nearby face."
        lastCheck = now(); generation = UUID(); checking = true
        audioDeadline?.cancel(); audioDeadline = nil; receivingAudio = false
        message = demo ? "DEMO · Simulated TrueDepth check" : "Brief TrueDepth check · tap to wake"
        let id = generation
        // Stop microphone during the bounded camera check; never run continuous camera capture.
        sensors.stop()
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.completeCheck(found: false, id: id, timedOut: true)
        }
        if !demo { sensors.checkFace { [weak self] found in self?.completeCheck(found: found, id: id) } }
    }
    private func completeCheck(found: Bool, id: UUID, timedOut: Bool = false) {
        guard generation == id, dimmed, checking, active, available else { return }
        deadline?.cancel(); deadline = nil; sensors.stop(); checking = false; generation = UUID()
        if found {
            lastDetection = demo ? "DEMO · Simulated face wake." : "Sound and nearby face detected · display awakened."
            wake()
        }
        else {
            lastDetection = demo ? "DEMO · No face confirmed." : (timedOut ? "Sound detected; TrueDepth timed out. Choose Sound to wake without a face check." : "Sound detected; no nearby face confirmed. Choose Sound to wake without a face check.")
            gate = StandbySoundGate(sensitivity: sensitivity)
            if !demo, permitted { startListening() }
            else { message = demo ? "DEMO · No face; staying dimmed" : "Tap to wake." }
        }
    }
    func simulateFace(_ found: Bool) { guard demo else { return }; completeCheck(found: found, id: generation) }
    private func cancelSensors() {
        audioDeadline?.cancel(); audioDeadline = nil; receivingAudio = false
        generation = UUID(); deadline?.cancel(); deadline = nil; sensors.stop(); checking = false
    }
    func wake() {
        cancelSensors()
        if let previousBrightness { writeBrightness(previousBrightness); self.previousBrightness = nil }
        dimmed = false; lastActivity = now()
        message = enabled ? (demo ? "DEMO · Sensors are simulated" : (setupIssue ?? "Ready. Sensors start only while dimmed.")) : "Off. Your camera and microphone are not used."
    }
}

struct StandbySettings: View {
    @ObservedObject var standby: StandbyStore
    let begin: () -> Void
    var body: some View {
        Form {
            Section("Foreground standby") {
                Toggle("Dim when idle; keep app awake", isOn: $standby.enabled).accessibilityIdentifier("standbyEnabled")
                Text("Keeps the current dashboard visible at minimum screen brightness. It does not lock or turn off the display. Touch restores your previous brightness. Automatic dimming waits until wake permissions are ready.").font(.footnote)
                Picker("Dim after", selection: $standby.delay) {
                    Text("30 seconds").tag(30.0); Text("1 minute").tag(60.0); Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0)
                }
            }
            Section("Wake detection") {
                Picker("Wake using", selection: $standby.mode) {
                    ForEach(StandbyWakeMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("standbyWakeMode")
                Text("Sound is the default: a noticeable sound directly restores brightness, with no camera. Sound + TrueDepth also requires a nearby face; if no face is confirmed, the display stays dim. Checks last up to 3 seconds and unsuccessful checks wait at least 15 seconds before retrying. Neither mode recognizes a specific wake word.").font(.footnote)
                Picker("Sound sensitivity", selection: $standby.sensitivity) {
                    ForEach(StandbySoundSensitivity.allCases, id: \.self) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("standbySensitivity")
                Text("Use High for quieter sounds; use Low if TV or background noise wakes the display. Allow a brief quiet moment after dimming for room calibration.").font(.footnote)
                if !standby.demo && !standby.hasTrueDepth { Text("No front TrueDepth camera is available. Choose Sound or use touch. The regular camera is never substituted.") }
                if standby.demo { Text("DEMO · No microphone or camera access. Wake controls simulate events.").accessibilityIdentifier("standbyDemoNotice") }
                else {
                    Button("Allow microphone / TrueDepth") { Task { await standby.requestPermissions() } }.disabled(standby.requesting).accessibilityIdentifier("standbyPermissions")
                    Button("Open iPad permission settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Text(standby.message).font(.footnote).accessibilityIdentifier("standbyStatus")
                Text(standby.lastDetection).font(.footnote).accessibilityIdentifier("standbyLastDetection")
                Toggle("Show sound level while dimmed", isOn: $standby.showSoundLevels)
                    .accessibilityIdentifier("standbySoundLevels")
                Text("Optional input and trigger levels help check sensitivity. Only sound levels are measured; no audio is saved.").font(.footnote)
            }
            Section("Privacy and limits") {
                Text("The microphone runs only while dimmed (orange indicator). TrueDepth is off except for a short check (camera indicator); its front image and depth are used for face presence, never identity. Nothing is recorded, saved or uploaded. Detection stops when you wake, leave the app, or open a panel. Audio playback pauses standby. It cannot unlock iPad or reopen the app after a lock or restart.").font(.footnote)
            }
            Section {
                Button("Start standby now", action: begin).disabled(!standby.enabled || standby.requesting || standby.setupIssue != nil).accessibilityIdentifier("standbyNow")
            }
        }
        .task(id: "\(standby.enabled)-\(standby.mode.rawValue)-\(standby.demo)") {
            if standby.enabled && !standby.demo { await standby.requestPermissions() }
        }
    }
}

/// Observes foreground taps without letting a SwiftUI ancestor gesture consume List buttons.
struct StandbyActivityObserver: UIViewRepresentable {
    let activity: () -> Void
    func makeUIView(context: Context) -> ActivityView {
        let view = ActivityView(); view.isUserInteractionEnabled = false; view.accessibilityElementsHidden = true
        return view
    }
    func updateUIView(_ view: ActivityView, context: Context) { view.activity = activity }
    static func dismantleUIView(_ view: ActivityView, coordinator: ()) { view.detach() }

    final class ActivityView: UIView, UIGestureRecognizerDelegate {
        var activity: (() -> Void)?
        private weak var observedWindow: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(touched))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false; recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()
        override func didMoveToWindow() {
            super.didMoveToWindow(); detach()
            observedWindow = window; window?.addGestureRecognizer(tap)
        }
        func detach() { observedWindow?.removeGestureRecognizer(tap); observedWindow = nil }
        @objc private func touched() { activity?() }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
