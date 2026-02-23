// PitchDetector.swift
// FretShed — Audio Layer (Phase 5)
//
// Captures microphone input via AVAudioEngine and detects the
// dominant pitch using the YIN algorithm — a robust time-domain
// fundamental frequency estimator well-suited to guitar.
//
// Usage:
//   let detector = PitchDetector()
//   try await detector.start()
//   // observe detector.detectedNote / detector.detectedFrequency
//   await detector.stop()
//
// The class is @MainActor so all @Observable properties update on
// the main thread and can be bound directly to SwiftUI views.

import AVFoundation
import Accelerate
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "PitchDetector")

// MARK: - PitchDetectorError

public enum PitchDetectorError: LocalizedError {
    case microphonePermissionDenied
    case audioSessionSetupFailed(Error)
    case engineStartFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Enable it in Settings → Privacy → Microphone."
        case .audioSessionSetupFailed(let e):
            return "Audio session setup failed: \(e.localizedDescription)"
        case .engineStartFailed(let e):
            return "Audio engine failed to start: \(e.localizedDescription)"
        }
    }
}

// MARK: - PitchDetector

@MainActor
@Observable
public final class PitchDetector {

    // MARK: - Public State

    /// The most recently detected musical note, or nil if no pitch is confident enough.
    public private(set) var detectedNote: MusicalNote? = nil

    /// The raw detected frequency in Hz, or nil when silent / unconfident.
    public private(set) var detectedFrequency: Double? = nil

    /// Cents deviation from the nearest equal-temperament pitch (-50 … +50).
    public private(set) var centsDeviation: Double = 0

    /// Microphone input level (0.0–1.0), mapped from RMS on a dB scale.
    public private(set) var inputLevel: Double = 0

    /// Whether the engine is currently running.
    public private(set) var isRunning: Bool = false

    /// Non-nil when an error prevents audio from running.
    public private(set) var error: PitchDetectorError? = nil

    // MARK: - Configuration

    /// Reference frequency for A4 (default 440 Hz, configurable for 432 Hz tuning).
    public var referenceA: Double = 440.0

    /// Minimum confidence (0–1) required before publishing a detected note.
    /// Higher = fewer false positives. Matches UserSettings.confidenceThreshold.
    public var confidenceThreshold: Float = 0.85

    /// When true, forces the audio session to use the built-in microphone,
    /// ignoring any connected Bluetooth or wired headset mic.
    public var forceBuiltInMic: Bool = false

    // MARK: - Calibration

    /// Pre-seeded noise floor from calibration profile. When set, the tap's
    /// adaptive noise floor starts from this value instead of the default 0.01.
    public var calibratedNoiseFloor: Float? = nil

    /// Pre-seeded AGC gain from calibration profile. When set, the tap's
    /// AGC starts from this value instead of the default 2.0.
    public var calibratedAGCGain: Float? = nil

    /// Optional frequency range constraint. When set, the consumer task
    /// ignores detected frequencies outside this range. Used by QuizView
    /// to narrow detection to the target string's frequency band.
    public var expectedFrequencyRange: ClosedRange<Double>? = nil

    /// Current noise floor as reported by the realtime tap (read-only for UI).
    public private(set) var currentNoiseFloor: Float = 0.01

    /// Current AGC gain as reported by the realtime tap (read-only for UI).
    public private(set) var currentAGCGain: Float = 2.0

    // MARK: - Audio Engine

    // Engine is a `var` so it can be recreated after interruptions or route changes.
    private var engine = AVAudioEngine()

    // YIN buffer size: 4096 samples at 44100 Hz ≈ 93 ms window — good for guitar fundamentals
    private let bufferSize: AVAudioFrameCount = 4096

    /// Realtime-safe atomic flag. Set to true before teardown to stop the
    /// audio tap from processing further buffers. Uses raw os_unfair_lock
    /// with no Swift concurrency involvement — safe to read on the audio thread.
    private let _isStopping = AudioAtomicFlag(false)

    /// Task that drains the pitch stream and updates published properties.
    private var _consumerTask: Task<Void, Never>? = nil

    // MARK: - Start / Stop

    /// Requests microphone permission and starts the audio engine.
    /// Throws `PitchDetectorError` on failure.
    public func start() async throws {
        guard !isRunning else { return }

        // 1. Permission
        let permitted = await requestMicrophonePermission()
        guard permitted else {
            error = .microphonePermissionDenied
            throw PitchDetectorError.microphonePermissionDenied
        }

        // 2. Audio session — must be active BEFORE accessing inputNode.
        //    Using .playAndRecord with .measurement mode avoids an internal
        //    engine assertion on the realtime thread seen with .record alone.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.defaultToSpeaker, .mixWithOthers])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(Double(bufferSize) / 44100.0)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Force built-in mic if requested. Must be set AFTER setActive.
            if forceBuiltInMic {
                if let builtIn = session.availableInputs?.first(where: {
                    $0.portType == .builtInMic
                }) {
                    try session.setPreferredInput(builtIn)
                    logger.info("Forced built-in microphone: \(builtIn.portName)")
                } else {
                    logger.warning("forceBuiltInMic requested but no built-in mic found")
                }
            } else {
                // Clear any previously forced input so routing reverts to system default.
                try session.setPreferredInput(nil)
            }
        } catch {
            let wrapped = PitchDetectorError.audioSessionSetupFailed(error)
            self.error = wrapped
            throw wrapped
        }

        // 3. Recreate the engine so we start with a clean graph.
        //    Reusing a stopped AVAudioEngine can leave inputNode in an invalid state.
        engine = AVAudioEngine()
        _isStopping.set(false)

        // 4. Log the resolved session sample rate.
        //    NOTE: Do NOT call engine.prepare() here. AVAudioEngine throws an
        //    NSException (uncatchable in Swift) if the hardware input node hasn't
        //    fully resolved its format yet. engine.start() calls prepare()
        //    internally at the correct time, after the tap is installed.
        let sessionSampleRate = AVAudioSession.sharedInstance().sampleRate
        logger.info("Audio session active, sample rate: \(sessionSampleRate)")

        // 5. Install tap — use inputFormat (not outputFormat) and an explicit
        //    mono Float32 format to avoid hardware channel-count mismatches.
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        logger.info("Input node format — sampleRate: \(hardwareFormat.sampleRate), channels: \(hardwareFormat.channelCount)")
        let tapSampleRate = hardwareFormat.sampleRate > 0 ? hardwareFormat.sampleRate : 44100.0
        guard let tapFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: tapSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            let wrapped = PitchDetectorError.engineStartFailed(
                NSError(domain: "PitchDetector", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not create tap format"])
            )
            self.error = wrapped
            throw wrapped
        }
        // Snapshot all @MainActor values needed by the realtime callback.
        // The tap closure must be @Sendable and capture only Sendable types —
        // no reference to `self` at all, since PitchDetector is @MainActor and
        // any access to it (even reading a `weak` reference) causes Swift's
        // runtime to insert an actor-isolation check that crashes on the audio thread.
        let isStopping = _isStopping
        let threshold = confidenceThreshold

        // AsyncStream is the safe bridge between the realtime audio thread and
        // the main actor. The continuation is a pure Sendable value type —
        // no actor reference is ever touched on the audio thread. The yielding
        // closure is @Sendable and does nothing except enqueue a value.
        let (pitchStream, pitchContinuation) = AsyncStream.makeStream(of: DetectedPitch.self,
                                                                      bufferingPolicy: .bufferingNewest(1))

        // Build the tap closure outside the @MainActor context by delegating to
        // a free function. A closure formed inside an @MainActor method carries
        // an implicit isolation assertion in its thunk — AVAudioEngine calls the
        // tap on a private realtime queue, which makes that assertion fatal.
        let playbackTS = MetroDroneEngine.lastPlaybackTime
        let calNoiseFloor = calibratedNoiseFloor
        let calAGCGain = calibratedAGCGain
        let tapClosure = makeTapClosure(
            isStopping: isStopping,
            confidenceThreshold: threshold,
            sampleRate: tapSampleRate,
            continuation: pitchContinuation,
            playbackTimestamp: playbackTS,
            calibratedNoiseFloor: calNoiseFloor,
            calibratedAGCGain: calAGCGain
        )
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: tapFormat, block: tapClosure)

        // Consume the stream on the main actor. This task holds no reference
        // to self until it is already executing on the main actor, which is safe.
        _consumerTask = Task { @MainActor [weak self] in
            var smoothedCents: Double = 0
            var smoothedLevel: Double = 0
            var freqHistory: [Double] = []
            // Pitch hold: sustain the last detection briefly after the gate closes so the
            // tuner needle doesn't snap back to centre as the note decays (fixes T2, T3).
            var holdUntilDate: Date? = nil
            let holdDuration: TimeInterval = 0.25   // 250 ms
            // Consecutive frame gate: require the same note for N frames before
            // publishing to detectedNote, preventing transient slide noise artifacts.
            var consecutiveNoteCount: Int = 0
            var lastConsecutiveNote: MusicalNote? = nil
            let consecutiveFrameThreshold = 3  // ~69ms at 23ms hop
            for await result in pitchStream {
                guard let self else { break }
                switch result {
                case .none:
                    // Within hold window: keep existing note/cents on screen.
                    if let until = holdUntilDate, until > Date() { break }
                    smoothedCents = 0
                    smoothedLevel = 0
                    freqHistory.removeAll()
                    self.detectedNote = nil
                    self.detectedFrequency = nil
                    self.centsDeviation = 0
                    self.inputLevel = 0
                    holdUntilDate = nil
                    consecutiveNoteCount = 0
                    lastConsecutiveNote = nil
                case .silent(let rmsLevel, let noiseFloor, let agcGain):
                    // Publish realtime signal state for calibration / diagnostics.
                    self.currentNoiseFloor = noiseFloor
                    self.currentAGCGain = agcGain
                    // Always update the level indicator (shows signal truly silent).
                    smoothedLevel = 0.3 * Double(rmsLevel) + 0.7 * smoothedLevel
                    self.inputLevel = smoothedLevel
                    // Within hold window: keep existing note/cents on screen.
                    if let until = holdUntilDate, until > Date() { break }
                    smoothedCents = 0
                    freqHistory.removeAll()
                    self.detectedNote = nil
                    self.detectedFrequency = nil
                    self.centsDeviation = 0
                    holdUntilDate = nil
                    consecutiveNoteCount = 0
                    lastConsecutiveNote = nil
                case .detected(let freq, let rmsLevel, let noiseFloor, let agcGain):
                    // Publish realtime signal state for calibration / diagnostics.
                    self.currentNoiseFloor = noiseFloor
                    self.currentAGCGain = agcGain
                    // Median filter: detect note changes and maintain sliding window
                    if !freqHistory.isEmpty {
                        let currentMedian = freqHistory.sorted()[freqHistory.count / 2]
                        if abs(freq - currentMedian) / currentMedian > 0.10 {
                            freqHistory.removeAll()
                        }
                    }
                    freqHistory.append(freq)
                    if freqHistory.count > 5 { freqHistory.removeFirst() }

                    // Use median frequency when we have enough samples
                    let useFreq: Double
                    if freqHistory.count >= 3 {
                        let sorted = freqHistory.sorted()
                        useFreq = sorted[sorted.count / 2]
                    } else {
                        useFreq = freq
                    }

                    // String-aware frequency constraint: reject frequencies outside expected range.
                    if let range = self.expectedFrequencyRange, !range.contains(useFreq) {
                        break
                    }

                    let (note, cents) = pitchDetectorNoteAndCents(frequency: useFreq, referenceA: self.referenceA)

                    // Consecutive frame gate: same note must persist for N frames
                    // before publishing, rejecting transient string slide artifacts.
                    if note == lastConsecutiveNote {
                        consecutiveNoteCount += 1
                    } else {
                        consecutiveNoteCount = 1
                        lastConsecutiveNote = note
                    }

                    smoothedLevel = 0.3 * Double(rmsLevel) + 0.7 * smoothedLevel
                    self.inputLevel = smoothedLevel

                    guard consecutiveNoteCount >= consecutiveFrameThreshold else {
                        // Still building up — keep previous note on screen via hold.
                        if self.detectedNote != nil {
                            holdUntilDate = Date().addingTimeInterval(holdDuration)
                        }
                        break
                    }

                    smoothedCents = 0.3 * cents + 0.7 * smoothedCents
                    // Extend hold window on every fresh detection.
                    holdUntilDate = Date().addingTimeInterval(holdDuration)
                    self.detectedNote = note
                    self.detectedFrequency = useFreq
                    // Dead-zone: skip sub-cent jitter
                    if abs(smoothedCents - self.centsDeviation) >= 0.5 {
                        self.centsDeviation = smoothedCents
                    }
                }
            }
        }

        // 6. Start engine
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            let wrapped = PitchDetectorError.engineStartFailed(error)
            self.error = wrapped
            throw wrapped
        }

        // 7. Handle audio session interruptions (calls, Siri, other apps)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .ended {
                Task { @MainActor [weak self] in
                    try? self?.engine.start()
                }
            }
        }

        // 8. Handle audio route changes (headphones unplugged, BT disconnected)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                logger.info("Audio route changed — restarting engine")
                self.engine.inputNode.removeTap(onBus: 0)
                self.engine.stop()
                self.engine = AVAudioEngine()
                let inputNode = self.engine.inputNode
                let hwFormat = inputNode.inputFormat(forBus: 0)
                let sr = hwFormat.sampleRate > 0 ? hwFormat.sampleRate : 44100.0
                guard let fmt = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32, sampleRate: sr,
                    channels: 1, interleaved: false
                ) else { return }
                let newTap = makeTapClosure(
                    isStopping: isStopping,
                    confidenceThreshold: threshold,
                    sampleRate: sr,
                    continuation: pitchContinuation,
                    playbackTimestamp: playbackTS,
                    calibratedNoiseFloor: calNoiseFloor,
                    calibratedAGCGain: calAGCGain
                )
                inputNode.installTap(onBus: 0, bufferSize: self.bufferSize, format: fmt, block: newTap)
                try? self.engine.start()
            }
        }

        isRunning = true
        self.error = nil
        logger.info("PitchDetector started (referenceA: \(self.referenceA) Hz)")
    }

    /// Stops the audio engine and removes the tap.
    public func stop() async {
        _isStopping.set(true)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        _consumerTask?.cancel()
        _consumerTask = nil
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        guard isRunning else {
            _isStopping.set(false)
            return
        }
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)
        isRunning = false
        _isStopping.set(false)
        detectedNote = nil
        detectedFrequency = nil
        centsDeviation = 0
        inputLevel = 0
        logger.info("PitchDetector stopped")
    }

    // MARK: - Helpers

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
// MARK: - AudioAtomicFlag
//
// A lock-protected Bool using raw os_unfair_lock with no Swift concurrency
// involvement whatsoever. This is safe to call from the AVAudioEngine
// realtime thread because os_unfair_lock_lock/unlock are plain C functions —
// Swift's actor isolation checker never sees them.

private final class AudioAtomicFlag: @unchecked Sendable {
    private var _lock = os_unfair_lock()
    private var _value: Bool

    init(_ value: Bool) { _value = value }

    func set(_ newValue: Bool) {
        os_unfair_lock_lock(&_lock)
        _value = newValue
        os_unfair_lock_unlock(&_lock)
    }

    func get() -> Bool {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return _value
    }
}

/// Result type passed from the realtime audio thread back to the main actor.
/// The consumer recomputes note/cents from the live referenceA, so we only
/// pass frequency and RMS level from the tap.
private enum DetectedPitch: Sendable {
    case none
    case silent(rmsLevel: Float, noiseFloor: Float, agcGain: Float)
    case detected(frequency: Double, rmsLevel: Float, noiseFloor: Float, agcGain: Float)
}

// MARK: - AccelerateYIN

/// FFT-based YIN pitch detector. Computes the difference function via
/// autocorrelation (IFFT of |FFT(x)|^2) reducing complexity from O(N^2)
/// to O(N log N). All buffers are pre-allocated as raw pointers at init —
/// zero heap allocation during detectPitch. Safe on the realtime thread.
private final class AccelerateYIN: @unchecked Sendable {
    private let windowSize: Int       // N (e.g. 4096)
    private let halfN: Int            // N / 2
    private let fftN: Int             // 2 * N (zero-padded for linear autocorrelation)
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup

    // Pre-allocated raw buffers — stable pointers, no Array overhead.
    private let realp: UnsafeMutablePointer<Float>     // fftN/2
    private let imagp: UnsafeMutablePointer<Float>     // fftN/2
    private let realp2: UnsafeMutablePointer<Float>    // fftN/2
    private let imagp2: UnsafeMutablePointer<Float>    // fftN/2
    private let diffBuf: UnsafeMutablePointer<Float>   // halfN
    private let cmndBuf: UnsafeMutablePointer<Float>   // halfN
    private let sqBuf: UnsafeMutablePointer<Float>     // windowSize
    private let hannWindow: UnsafeMutablePointer<Float>   // windowSize
    private let windowedBuf: UnsafeMutablePointer<Float>  // windowSize
    private let logBuf: UnsafeMutablePointer<Float>       // fftN/2 (scratch for spectral flatness)

    init(windowSize: Int = 4096) {
        self.windowSize = windowSize
        self.halfN = windowSize / 2
        self.fftN = windowSize * 2
        let log2 = vDSP_Length(log2(Double(windowSize * 2)))
        self.log2n = log2
        self.fftSetup = vDSP_create_fftsetup(log2, FFTRadix(kFFTRadix2))!

        let halfFFT = windowSize  // fftN / 2
        realp = .allocate(capacity: halfFFT); realp.initialize(repeating: 0, count: halfFFT)
        imagp = .allocate(capacity: halfFFT); imagp.initialize(repeating: 0, count: halfFFT)
        realp2 = .allocate(capacity: halfFFT); realp2.initialize(repeating: 0, count: halfFFT)
        imagp2 = .allocate(capacity: halfFFT); imagp2.initialize(repeating: 0, count: halfFFT)
        diffBuf = .allocate(capacity: windowSize / 2); diffBuf.initialize(repeating: 0, count: windowSize / 2)
        cmndBuf = .allocate(capacity: windowSize / 2); cmndBuf.initialize(repeating: 0, count: windowSize / 2)
        sqBuf = .allocate(capacity: windowSize); sqBuf.initialize(repeating: 0, count: windowSize)
        hannWindow = .allocate(capacity: windowSize)
        vDSP_hann_window(hannWindow, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        windowedBuf = .allocate(capacity: windowSize); windowedBuf.initialize(repeating: 0, count: windowSize)
        logBuf = .allocate(capacity: halfFFT); logBuf.initialize(repeating: 0, count: halfFFT)
    }

    deinit {
        let halfFFT = fftN / 2
        realp.deinitialize(count: halfFFT); realp.deallocate()
        imagp.deinitialize(count: halfFFT); imagp.deallocate()
        realp2.deinitialize(count: halfFFT); realp2.deallocate()
        imagp2.deinitialize(count: halfFFT); imagp2.deallocate()
        diffBuf.deinitialize(count: halfN); diffBuf.deallocate()
        cmndBuf.deinitialize(count: halfN); cmndBuf.deallocate()
        sqBuf.deinitialize(count: windowSize); sqBuf.deallocate()
        hannWindow.deallocate()
        windowedBuf.deinitialize(count: windowSize); windowedBuf.deallocate()
        logBuf.deinitialize(count: fftN / 2); logBuf.deallocate()
        vDSP_destroy_fftsetup(fftSetup)
    }

    func detectPitch(
        in samples: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double
    ) -> (frequency: Double, confidence: Double, spectralFlatness: Float)? {
        let n = min(count, windowSize)
        guard n >= windowSize else { return nil }
        let halfFFT = fftN / 2

        // --- Step 1: FFT-based difference function ---
        // d(tau) = energy[0..N-tau] + energy[tau..N] - 2 * autocorr(tau)
        //
        // autocorr via FFT: zero-pad x to 2N, then IFFT(|FFT(x)|^2)

        // Apply Hann window to reduce spectral leakage
        vDSP_vmul(samples, 1, hannWindow, 1, windowedBuf, 1, vDSP_Length(windowSize))

        // Zero the FFT buffers
        vDSP_vclr(realp, 1, vDSP_Length(halfFFT))
        vDSP_vclr(imagp, 1, vDSP_Length(halfFFT))

        // Pack the windowed signal into split-complex form for vDSP_fft_zrip.
        // vDSP split-complex packing: even indices → real, odd indices → imag.
        for i in 0..<(windowSize / 2) {
            realp[i] = windowedBuf[2 * i]
            imagp[i] = windowedBuf[2 * i + 1]
        }

        // Forward FFT
        var splitComplex = DSPSplitComplex(realp: realp, imagp: imagp)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Power spectrum: |FFT(x)|^2
        vDSP_zvmags(&splitComplex, 1, realp2, 1, vDSP_Length(halfFFT))

        // --- Spectral Flatness (before inverse FFT overwrites realp2) ---
        // Tonal signals ~0.01–0.15; string slide noise ~0.3–0.8.
        var sfArithMean: Float = 0
        vDSP_meanv(realp2, 1, &sfArithMean, vDSP_Length(halfFFT))
        let spectralFlatness: Float
        if sfArithMean > 1e-20 {
            var sfEpsilon: Float = 1e-20
            vDSP_vsadd(realp2, 1, &sfEpsilon, logBuf, 1, vDSP_Length(halfFFT))
            var sfCount = Int32(halfFFT)
            vvlogf(logBuf, logBuf, &sfCount)
            var sfLogMean: Float = 0
            vDSP_meanv(logBuf, 1, &sfLogMean, vDSP_Length(halfFFT))
            spectralFlatness = expf(sfLogMean) / sfArithMean
        } else {
            spectralFlatness = 1.0
        }

        // --- HPS (Harmonic Product Spectrum) peak detection ---
        // Multiply spectrum with 2× and 3× downsampled versions to find
        // the true fundamental. Helps correct octave errors on low strings
        // where harmonics are stronger than the fundamental.
        let hpsMinBin = max(1, Int(75.0 * Double(fftN) / sampleRate))
        let hpsMaxBin = min(halfFFT / 3 - 1, Int(700.0 * Double(fftN) / sampleRate))
        var hpsFundamentalHz: Double = 0
        if hpsMinBin < hpsMaxBin {
            for k in hpsMinBin...hpsMaxBin {
                logBuf[k - hpsMinBin] = realp2[k] * realp2[2 * k] * realp2[3 * k]
            }
            var hpsPeakVal: Float = 0
            var hpsPeakIdx: vDSP_Length = 0
            vDSP_maxvi(logBuf, 1, &hpsPeakVal, &hpsPeakIdx, vDSP_Length(hpsMaxBin - hpsMinBin + 1))
            if hpsPeakVal > 0 {
                hpsFundamentalHz = Double(Int(hpsPeakIdx) + hpsMinBin) * sampleRate / Double(fftN)
            }
        }

        vDSP_vclr(imagp2, 1, vDSP_Length(halfFFT))

        // Inverse FFT of power spectrum → autocorrelation
        var powerSplit = DSPSplitComplex(realp: realp2, imagp: imagp2)
        vDSP_fft_zrip(fftSetup, &powerSplit, 1, log2n, FFTDirection(kFFTDirection_Inverse))

        // vDSP inverse FFT doesn't normalize — scale by 1/(2*fftN)
        let scale = 1.0 / Float(2 * fftN)

        // Compute cumulative energy for the difference function (from windowed signal)
        vDSP_vsq(windowedBuf, 1, sqBuf, 1, vDSP_Length(windowSize))
        var cumEnergy: Float = 0
        for i in 0..<windowSize {
            cumEnergy += sqBuf[i]
            sqBuf[i] = cumEnergy
        }
        let totalEnergy = sqBuf[windowSize - 1]

        // Build difference function:
        // d(tau) = energy(0, N-tau) + energy(tau, N) - 2 * autocorr(tau)
        diffBuf[0] = 0
        for tau in 1..<halfN {
            // Retrieve autocorrelation at lag `tau` from split-complex layout
            let autocorrRaw = (tau % 2 == 0) ? realp2[tau / 2] : imagp2[tau / 2]
            let autocorr = autocorrRaw * scale
            let energyHead = sqBuf[windowSize - tau - 1]
            let energyTail = totalEnergy - sqBuf[tau - 1]
            diffBuf[tau] = energyHead + energyTail - 2.0 * autocorr
        }

        // --- Step 2: Cumulative mean normalised difference ---
        cmndBuf[0] = 1.0
        var runningSum: Float = 0
        for tau in 1..<halfN {
            runningSum += diffBuf[tau]
            cmndBuf[tau] = runningSum > 0 ? diffBuf[tau] * Float(tau) / runningSum : 1.0
        }

        // --- Step 3: Absolute threshold ---
        let yinThreshold: Float = 0.15
        let minTau = max(1, Int(sampleRate / 1175.0))
        let maxTau = min(Int(sampleRate / 80.0), halfN - 1)
        guard minTau < maxTau else { return nil }

        var bestTau = -1
        for tau in minTau..<maxTau {
            if cmndBuf[tau] < yinThreshold {
                var t = tau
                while t + 1 < maxTau && cmndBuf[t + 1] < cmndBuf[t] { t += 1 }
                bestTau = t
                break
            }
        }

        if bestTau == -1 {
            var minVal: Float = .greatestFiniteMagnitude
            for tau in minTau..<maxTau {
                if cmndBuf[tau] < minVal { minVal = cmndBuf[tau]; bestTau = tau }
            }
        }

        guard bestTau > 0 else { return nil }

        // --- Step 3b: Octave error correction ---
        // The absolute-threshold search picks the FIRST CMND minimum, which can
        // land on a harmonic period (τ₀/2 → 2× fundamental) — especially on the
        // low E and A strings through a built-in microphone.
        // Fix: check if double-tau also has a strong local minimum. If so, prefer
        // the lower frequency (larger τ = true fundamental).
        let doubleTau = bestTau * 2
        if doubleTau < maxTau {
            var dt = doubleTau
            while dt + 1 < maxTau && cmndBuf[dt + 1] < cmndBuf[dt] { dt += 1 }
            if cmndBuf[dt] < 0.35 { bestTau = dt }
        }

        // --- Step 3c: HPS octave verification ---
        // If YIN frequency is still ~2× the HPS fundamental after double-tau
        // correction, HPS provides independent evidence the true fundamental
        // is an octave lower. Apply correction with a relaxed CMND threshold.
        if hpsFundamentalHz > 0 {
            let yinFreq = sampleRate / Double(bestTau)
            let ratio = yinFreq / hpsFundamentalHz
            if ratio > 1.8 && ratio < 2.2 {
                let correctedTau = bestTau * 2
                if correctedTau < maxTau {
                    var ct = correctedTau
                    while ct + 1 < maxTau && cmndBuf[ct + 1] < cmndBuf[ct] { ct += 1 }
                    if cmndBuf[ct] < 0.50 {
                        bestTau = ct
                    }
                }
            }
        }

        // --- Step 4: Parabolic interpolation ---
        let interpolatedTau: Double
        if bestTau > 0 && bestTau < halfN - 1 {
            let s0 = cmndBuf[bestTau - 1], s1 = cmndBuf[bestTau], s2 = cmndBuf[bestTau + 1]
            let denom = 2.0 * (s0 - 2.0 * s1 + s2)
            interpolatedTau = abs(denom) > 1e-10
                ? Double(bestTau) + Double(s0 - s2) / Double(denom)
                : Double(bestTau)
        } else {
            interpolatedTau = Double(bestTau)
        }

        let frequency = sampleRate / interpolatedTau
        let confidence = 1.0 - Double(min(cmndBuf[bestTau], 1.0))
        return (frequency, confidence, spectralFlatness)
    }
}

// MARK: - RingBuffer

/// Fixed-capacity circular buffer for accumulating audio samples on the
/// realtime thread. Uses raw UnsafeMutablePointer — stable pointer, zero
/// heap allocation during append/read, no array copy-on-write races.
private final class AudioRingBuffer: @unchecked Sendable {
    private let buffer: UnsafeMutablePointer<Float>
    private let capacity: Int
    private var writePos: Int = 0
    private var filled: Int = 0     // how many valid samples total (capped at capacity)
    private var newSamples: Int = 0 // samples added since last analysis

    let hopSize: Int      // run analysis every this many new samples
    let windowSize: Int   // analysis window length

    init(capacity: Int, hopSize: Int, windowSize: Int) {
        self.capacity = capacity
        self.hopSize = hopSize
        self.windowSize = windowSize
        self.buffer = .allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    /// Appends samples to the ring buffer. Returns true if enough new
    /// samples have accumulated to warrant a new analysis pass.
    func append(_ samples: UnsafePointer<Float>, count: Int) -> Bool {
        for i in 0..<count {
            buffer[writePos] = samples[i]
            writePos = (writePos + 1) % capacity
        }
        filled = min(filled + count, capacity)
        newSamples += count

        if newSamples >= hopSize && filled >= windowSize {
            newSamples = 0
            return true
        }
        return false
    }

    /// Copies the most recent `windowSize` samples into the destination buffer
    /// in contiguous order.
    func copyLatest(into dest: UnsafeMutablePointer<Float>) {
        let start = (writePos - windowSize + capacity) % capacity
        if start + windowSize <= capacity {
            dest.update(from: buffer + start, count: windowSize)
        } else {
            let firstChunk = capacity - start
            let secondChunk = windowSize - firstChunk
            dest.update(from: buffer + start, count: firstChunk)
            (dest + firstChunk).update(from: buffer, count: secondChunk)
        }
    }
}

// MARK: - TapProcessingState

/// Bundles all mutable state needed by the audio tap into a single Sendable
/// class. This avoids capturing raw pointers directly in @Sendable closures.
private final class TapProcessingState: @unchecked Sendable {
    let yin: AccelerateYIN
    let ring: AudioRingBuffer
    let analysisBuffer: UnsafeMutablePointer<Float>
    private let windowSize: Int

    // High-pass biquad filter state (70 Hz Butterworth, persists across callbacks)
    var hpfZ1: Float = 0
    var hpfZ2: Float = 0
    let hpfB0: Float
    let hpfB1: Float
    let hpfB2: Float
    let hpfA1: Float
    let hpfA2: Float
    let filteredBuffer: UnsafeMutablePointer<Float>
    private let filteredBufferCapacity: Int

    // Adaptive noise gate state
    var noiseFloor: Float = 0.01

    // Auto-Gain Control: slow-adapting multiplier that normalises signal amplitude
    // so YIN sees consistent levels regardless of guitar type, distance, or input source.
    var agcGain: Float = 2.0          // initial ×2 boost for typical mic-to-guitar distance
    let agcTargetRMS: Float = 0.126   // −18 dBFS target
    let agcAdaptRate: Float = 0.002   // ~0.2% per frame → ~10 s to halve/double gain
    let agcMinGain: Float = 0.5
    let agcMaxGain: Float = 16.0

    init(windowSize: Int, hopSize: Int, ringCapacity: Int, sampleRate: Double) {
        self.windowSize = windowSize
        self.yin = AccelerateYIN(windowSize: windowSize)
        self.ring = AudioRingBuffer(capacity: ringCapacity, hopSize: hopSize, windowSize: windowSize)
        self.analysisBuffer = .allocate(capacity: windowSize)
        self.analysisBuffer.initialize(repeating: 0, count: windowSize)

        // Pre-allocate filtered buffer for HPF output
        self.filteredBufferCapacity = 8192
        self.filteredBuffer = .allocate(capacity: filteredBufferCapacity)
        self.filteredBuffer.initialize(repeating: 0, count: filteredBufferCapacity)

        // Compute 2nd-order Butterworth HPF coefficients (f0 = 60 Hz)
        // Lowered from 70 Hz to give full headroom for low E (82.4 Hz)
        // and support drop D tuning (73.4 Hz).
        let f0 = 60.0
        let q = 1.0 / sqrt(2.0)  // Butterworth Q
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosW0 = cos(w0)
        let a0 = 1.0 + alpha
        self.hpfB0 = Float((1.0 + cosW0) / 2.0 / a0)
        self.hpfB1 = Float(-(1.0 + cosW0) / a0)
        self.hpfB2 = Float((1.0 + cosW0) / 2.0 / a0)
        self.hpfA1 = Float(-2.0 * cosW0 / a0)
        self.hpfA2 = Float((1.0 - alpha) / a0)
    }

    func deallocate() {
        analysisBuffer.deinitialize(count: windowSize)
        analysisBuffer.deallocate()
        filteredBuffer.deinitialize(count: filteredBufferCapacity)
        filteredBuffer.deallocate()
    }
}

// MARK: - Realtime Processing (free functions — no actor context)

/// Constructs the AVAudioNode tap block as a free function with no actor
/// context. Captures a pre-allocated AccelerateYIN, ring buffer, and
/// analysis window — zero heap allocation per callback.
private func makeTapClosure(
    isStopping: AudioAtomicFlag,
    confidenceThreshold: Float,
    sampleRate: Double,
    continuation: AsyncStream<DetectedPitch>.Continuation,
    playbackTimestamp: PlaybackTimestamp,
    calibratedNoiseFloor: Float? = nil,
    calibratedAGCGain: Float? = nil
) -> AVAudioNodeTapBlock {
    let windowSize = 4096
    let hopSize = 1024
    let ringCapacity = 8192

    // Bundle all mutable tap state into a single Sendable class so the
    // tap closure and onTermination handler can capture it cleanly.
    let tapState = TapProcessingState(
        windowSize: windowSize,
        hopSize: hopSize,
        ringCapacity: ringCapacity,
        sampleRate: sampleRate
    )

    // Apply calibration values if available (pre-seeds the adaptive algorithms).
    if let nf = calibratedNoiseFloor { tapState.noiseFloor = nf }
    if let ag = calibratedAGCGain { tapState.agcGain = ag }

    // Clean up when the stream terminates
    continuation.onTermination = { @Sendable _ in
        tapState.deallocate()
    }

    return { buffer, _ in
        guard !isStopping.get() else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Apply high-pass biquad filter (70 Hz cutoff) to remove rumble/handling noise
        let state = tapState
        let fb = state.filteredBuffer
        let b0 = state.hpfB0, b1 = state.hpfB1, b2 = state.hpfB2
        let a1 = state.hpfA1, a2 = state.hpfA2
        var z1 = state.hpfZ1, z2 = state.hpfZ2
        for i in 0..<frameCount {
            let x = channelData[i]
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            fb[i] = y
        }
        state.hpfZ1 = z1
        state.hpfZ2 = z2

        // Append filtered signal to ring buffer
        let ready = state.ring.append(fb, count: frameCount)
        guard ready else { return }

        state.ring.copyLatest(into: state.analysisBuffer)

        // RMS gate on the analysis window
        let rms = SignalMeasurement.rms(buffer: state.analysisBuffer, count: windowSize)
        let rmsLevel = SignalMeasurement.normaliseToLevel(rms: rms)

        // Adaptive noise gate: tracks noise floor, sets threshold dynamically
        state.noiseFloor = SignalMeasurement.noiseFloorStep(current: state.noiseFloor, rms: rms)
        let gateThreshold = SignalMeasurement.gateThreshold(noiseFloor: state.noiseFloor)
        guard rms > gateThreshold else {
            continuation.yield(.silent(rmsLevel: rmsLevel, noiseFloor: state.noiseFloor, agcGain: state.agcGain))
            return
        }

        // Auto-Gain Control: adapt gain toward −18 dBFS target (only while gate is open).
        // This normalises amplitude across guitar types, distances, and input sources.
        let gainedRMS = rms * state.agcGain
        if gainedRMS < state.agcTargetRMS {
            state.agcGain = min(state.agcGain / (1.0 - state.agcAdaptRate), state.agcMaxGain)
        } else if gainedRMS > state.agcTargetRMS * 2.0 {
            state.agcGain = max(state.agcGain * (1.0 - state.agcAdaptRate), state.agcMinGain)
        }
        var agcMultiplier = state.agcGain
        vDSP_vsmul(state.analysisBuffer, 1, &agcMultiplier, state.analysisBuffer, 1, vDSP_Length(windowSize))
        let gainedLevel = SignalMeasurement.normaliseToLevel(rms: gainedRMS)

        // Blank analysis during metronome clicks / sound cues to prevent
        // acoustic speaker-to-mic feedback from being detected as notes.
        let lastPlayback = playbackTimestamp.get()
        if lastPlayback > 0 {
            let elapsed = CFAbsoluteTimeGetCurrent() - lastPlayback
            if elapsed >= 0 && elapsed < 0.15 {
                continuation.yield(.silent(rmsLevel: gainedLevel, noiseFloor: state.noiseFloor, agcGain: state.agcGain))
                return
            }
        }

        // Spectral flatness above this value indicates broadband noise (string slides,
        // handling noise) rather than a tonal signal. Guitar notes: ~0.01–0.15.
        let spectralFlatnessThreshold: Float = 0.35

        guard let (frequency, confidence, flatness) = state.yin.detectPitch(
            in: state.analysisBuffer,
            count: windowSize,
            sampleRate: sampleRate
        ), confidence >= Double(confidenceThreshold),
           flatness < spectralFlatnessThreshold else {
            continuation.yield(.none)
            return
        }

        continuation.yield(.detected(frequency: frequency, rmsLevel: gainedLevel, noiseFloor: state.noiseFloor, agcGain: state.agcGain))
    }
}

private func pitchDetectorNoteAndCents(frequency: Double, referenceA: Double) -> (MusicalNote, Double) {
    let midiFloat = 12.0 * log2(frequency / referenceA) + 69.0
    let midiRounded = midiFloat.rounded()
    let pitchClass = ((Int(midiRounded) % 12) + 12) % 12
    let note = MusicalNote(rawValue: pitchClass) ?? .a
    let cents = (midiFloat - midiRounded) * 100.0
    return (note, cents)
}


