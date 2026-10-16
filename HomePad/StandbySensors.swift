import AVFoundation
import Vision
import UIKit

/// Raw audio remains in the input buffer; only decibel levels reach the state machine.
@MainActor final class StandbySensors: StandbySensing {
    var hasTrueDepth: Bool { AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) != nil }
    var microphoneAllowed: Bool { AVAudioApplication.shared.recordPermission == .granted }
    var cameraAllowed: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
    private var engine: AVAudioEngine?
    private var tapInstalled = false
    private var probe: StandbyDepthProbe?
    private var observers: [NSObjectProtocol] = []
    private var previousCategory: AVAudioSession.Category?
    private var previousMode: AVAudioSession.Mode?
    private var previousOptions: AVAudioSession.CategoryOptions = []

    func requestPermissions(depth: Bool) async {
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        if depth, hasTrueDepth, AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }
    func listen(level: @escaping (Float) -> Void, failure: @escaping (String) -> Void) throws {
        stop()
        guard microphoneAllowed else { throw StandbySensorError.permission }
        let session = AVAudioSession.sharedInstance()
        previousCategory = session.category; previousMode = session.mode; previousOptions = session.categoryOptions
        do {
            // No background-audio entitlement: this is explicitly foreground-only.
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let engine = AVAudioEngine(); self.engine = engine
            let input = engine.inputNode, format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw StandbySensorError.input }
            // ~0.1 s buffers; no sample buffers are retained, and no speech transcription is used.
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate / 10), format: format) { buffer, _ in
                guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                var sum: Float = 0
                for index in 0..<Int(buffer.frameLength) { sum += data[index] * data[index] }
                let db = 20 * log10(max(0.000001, sqrt(sum / Float(buffer.frameLength))))
                Task { @MainActor in level(db) }
            }
            tapInstalled = true
            engine.prepare(); try engine.start()
            for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                         AVAudioSession.mediaServicesWereResetNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { notification in
                    if name == AVAudioSession.routeChangeNotification,
                       let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                       AVAudioSession.RouteChangeReason(rawValue: raw) == .categoryChange { return }
                    Task { @MainActor in failure("Audio changed or was interrupted.") }
                })
            }
        } catch { stop(); throw error }
    }
    func checkFace(completion: @escaping (Bool) -> Void) {
        stop()
        guard hasTrueDepth, cameraAllowed else { completion(false); return }
        let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        let probe = StandbyDepthProbe(orientation: orientation) { found in
            Task { @MainActor in completion(found) }
        }
        self.probe = probe; probe.start()
    }
    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
        if let engine {
            engine.stop()
            if tapInstalled { engine.inputNode.removeTap(onBus: 0) }
            tapInstalled = false; self.engine = nil
        }
        if let category = previousCategory {
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(category, mode: previousMode ?? .default, options: previousOptions)
            previousCategory = nil; previousMode = nil
        }
        probe?.cancel(); probe = nil
    }
}

private enum StandbySensorError: Error { case permission, input, depth }

/// One short, serialized TrueDepth capture. Synchronized face + depth evidence, no identity matching.
private final class StandbyDepthProbe: NSObject, AVCaptureDataOutputSynchronizerDelegate {
    private let queue = DispatchQueue(label: "org.homeviewpad.standby.depth", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let video = AVCaptureVideoDataOutput()
    private let depth = AVCaptureDepthDataOutput()
    private var synchronizer: AVCaptureDataOutputSynchronizer?
    private let orientation: UIInterfaceOrientation
    private let completion: (Bool) -> Void
    private let lock = NSLock()
    private var cancelled = false
    private var finished = false // Queue-confined.
    private var consecutiveFaces = 0
    private var lastFrame = CMTime.invalid
    init(orientation: UIInterfaceOrientation, completion: @escaping (Bool) -> Void) {
        self.orientation = orientation; self.completion = completion
    }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func start() { queue.async { self.configure() } }
    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        queue.async { self.teardown() }
    }
    private func configure() {
        guard !isCancelled else { return }
        do {
            guard let camera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else { throw StandbySensorError.depth }
            let formats = camera.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
            guard let format = formats.min(by: { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width }),
                  let depthFormat = format.supportedDepthDataFormats.first else { throw StandbySensorError.depth }
            let input = try AVCaptureDeviceInput(device: camera)
            session.beginConfiguration(); session.sessionPreset = .inputPriority
            guard session.canAddInput(input) else {
                session.commitConfiguration(); throw StandbySensorError.depth
            }
            session.addInput(input)
            guard session.canAddOutput(video) else { session.commitConfiguration(); throw StandbySensorError.depth }
            video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            video.alwaysDiscardsLateVideoFrames = true; depth.isFilteringEnabled = true
            session.addOutput(video)
            guard session.canAddOutput(depth) else { session.commitConfiguration(); throw StandbySensorError.depth }
            session.addOutput(depth)
            let angle: CGFloat
            switch orientation { case .landscapeLeft: angle = 180; case .landscapeRight: angle = 0; case .portraitUpsideDown: angle = 270; default: angle = 90 }
            let connections = [video.connection(with: .video), depth.connection(with: .depthData)].compactMap { $0 }
            guard connections.count == 2, connections.allSatisfy({ $0.isVideoRotationAngleSupported(angle) }) else {
                session.commitConfiguration(); throw StandbySensorError.depth
            }
            for connection in connections {
                connection.videoRotationAngle = angle
                if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false }
            }
            session.commitConfiguration()
            try camera.lockForConfiguration()
            camera.activeFormat = format; camera.activeDepthDataFormat = depthFormat
            if format.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 15 && $0.maxFrameRate >= 15 }) {
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            }
            camera.unlockForConfiguration()
            synchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [video, depth])
            synchronizer?.setDelegate(self, queue: queue)
            guard !isCancelled else { teardown(); return }
            session.startRunning()
            guard !isCancelled else { teardown(); return }
            queue.asyncAfter(deadline: .now() + 2.5) { self.finish(false) }
        } catch { finish(false) }
    }
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput collection: AVCaptureSynchronizedDataCollection) {
        guard !isCancelled, !finished,
              let v = collection.synchronizedData(for: video) as? AVCaptureSynchronizedSampleBufferData, !v.sampleBufferWasDropped,
              let d = collection.synchronizedData(for: depth) as? AVCaptureSynchronizedDepthData, !d.depthDataWasDropped,
              let buffer = CMSampleBufferGetImageBuffer(v.sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(v.sampleBuffer)
        if lastFrame.isValid && CMTimeGetSeconds(timestamp - lastFrame) < 0.2 { return }
        lastFrame = timestamp
        let request = VNDetectFaceRectanglesRequest()
        do { try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request]) }
        catch { consecutiveFaces = 0; return }
        let map = d.depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        let found = (request.results ?? []).contains { face in
            face.confidence >= 0.65 && Self.nearbyDepth(map, face: face.boundingBox)
        }
        consecutiveFaces = found ? consecutiveFaces + 1 : 0
        if consecutiveFaces >= 2 { finish(true) }
    }
    private static func nearbyDepth(_ map: CVPixelBuffer, face: CGRect) -> Bool {
        CVPixelBufferLockBaseAddress(map, .readOnly); defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return false }
        let width = CVPixelBufferGetWidth(map), height = CVPixelBufferGetHeight(map), stride = CVPixelBufferGetBytesPerRow(map) / MemoryLayout<Float32>.size
        guard width > 0, height > 0, stride >= width else { return false }
        let values = base.assumingMemoryBound(to: Float32.self)
        var distances: [Float32] = []
        for xOffset in [-0.15, 0.0, 0.15] {
            for yOffset in [-0.15, 0.0, 0.15] {
                let x = min(width - 1, max(0, Int((face.midX + face.width * xOffset) * Double(width))))
                let y = min(height - 1, max(0, Int((1 - face.midY + face.height * yOffset) * Double(height))))
                let value = values[y * stride + x]
                if value.isFinite && value > 0 { distances.append(value) }
            }
        }
        guard distances.count >= 5 else { return false }
        distances.sort(); return (0.2...2.0).contains(distances[distances.count / 2])
    }
    private func finish(_ found: Bool) {
        guard !finished else { return }; finished = true
        teardown()
        if !isCancelled { completion(found) }
    }
    private func teardown() {
        synchronizer?.setDelegate(nil, queue: nil); synchronizer = nil
        if session.isRunning { session.stopRunning() }
    }
}
