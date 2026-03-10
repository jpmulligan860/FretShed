// MetroDroneEngine.swift
// FretShed — Audio Layer
//
// Shared AVAudioEngine powering both the metronome click track and the
// continuous drone generator. Both paths feed into a single mixer so they
// can play simultaneously without audio conflicts.
//
// Thread-safety strategy for the drone:
//   DroneState uses fixed-size scalar fields (no Swift arrays) so every
//   read/write is naturally atomic on ARM64. The main thread writes config
//   fields (freq0-2, voiceCount, volume, soundMode, targetFadeGain,
//   isPlaying, needsPhaseReset). The audio thread reads those fields and
//   exclusively owns the phase/fade fields it writes every sample.

import AVFoundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "MetroDrone")

// MARK: - Sound Cue

enum SoundCue {
    case correct
    case incorrect
}

// MARK: - Drone Render (free function — must NOT inherit @MainActor isolation)

/// Real-time audio render callback for the drone source node.
/// Declared as a free function so it runs on the audio IO thread
/// without tripping libdispatch's main-actor queue assertion.
private func droneRenderBlock(
    state: MetroDroneEngine.DroneState,
    sampleRate: Double
) -> AVAudioSourceNodeRenderBlock {
    let twoPi = 2.0 * Double.pi

    return { _, _, frameCount, bufferList in
        let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let buf = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        let count = Int(frameCount)

        // Read config snapshot (each field is atomic on ARM64)
        let playing = state.isPlaying
        let targetGain = state.targetFadeGain
        var fadeGain = state.fadeGain
        let fadeInc = state.fadeIncrement

        // Fast path: fully silent
        if !playing && fadeGain <= 0.0001 {
            for i in 0..<count { buf[i] = 0 }
            return noErr
        }

        // Check if main thread requested a phase reset (voicing change)
        if state.needsPhaseReset {
            state.phase0 = 0
            state.phase1 = 0
            state.phase2 = 0
            state.warmPhase0 = 0
            state.warmPhase1 = 0
            state.warmPhase2 = 0
            state.lfoPhase = 0
            state.lpfState = 0
            state.needsPhaseReset = false
        }

        // Sync LFO phase to metronome beat
        if state.needsLFOPhaseReset {
            state.lfoPhase = 0
            state.needsLFOPhaseReset = false
        }

        let voices = state.voiceCount
        let mode = state.soundMode // 0=pure, 1=rich, 2=piano
        let vol = state.volume
        let f0 = state.freq0
        let f1 = state.freq1
        let f2 = state.freq2
        var p0 = state.phase0
        var p1 = state.phase1
        var p2 = state.phase2
        var lfoPhase = state.lfoPhase
        var lpfState = state.lpfState

        let inc0 = twoPi * f0 / sampleRate
        let inc1 = twoPi * f1 / sampleRate
        let inc2 = twoPi * f2 / sampleRate

        let detuneFactor = 1.0011552453009332 // pow(2.0, 2.0/1200.0) — +2 cents, precomputed
        let warmDetuneFactor = 1.004050       // pow(2.0, 7.0/1200.0) — +7 cents for audible chorus

        // Warm detuned oscillator state (always on)
        let warmGainVal = state.warmGain
        var wp0 = state.warmPhase0
        var wp1 = state.warmPhase1
        var wp2 = state.warmPhase2
        let wInc0 = twoPi * f0 * warmDetuneFactor / sampleRate
        let wInc1 = twoPi * f1 * warmDetuneFactor / sampleRate
        let wInc2 = twoPi * f2 * warmDetuneFactor / sampleRate
        let chorusFactor = 1.002              // +3.5 cents — piano chorus detune
        let inharmonicity = 0.0003            // B coefficient for piano wire stiffness
        let lfoInc = twoPi * state.lfoRateHz / sampleRate
        // 1-pole LPF coefficients: 4000 Hz for rich, 2500 Hz for piano
        let lpfAlphaRich  = Float(min(max(twoPi * 4000.0 / sampleRate, 0), 1))
        let lpfAlphaPiano = Float(min(max(twoPi * 2500.0 / sampleRate, 0), 1))

        for i in 0..<count {
            var sample: Double = 0

            // Voice 0 (root — always present when voices >= 1)
            if voices >= 1 {
                if mode == 1 { // rich
                    sample += sin(p0)
                    sample += 0.5 * sin(p0 * 0.5)
                    sample += 0.25 * sin(p0 * 1.5)
                    sample += 0.3 * sin(p0 * detuneFactor)
                    sample += 0.15 * sin(p0 * 3.0)
                    sample += 0.08 * sin(p0 * 5.0)
                } else if mode == 2 { // piano
                    sample += sin(p0)
                    sample += 0.35 * sin(p0 * chorusFactor)
                    sample += 0.4  * sin(p0 * 2.0 * (1 + inharmonicity))
                    sample += 0.3  * sin(p0 * 3.0 * (1 + 4 * inharmonicity))
                    sample += 0.15 * sin(p0 * 4.0 * (1 + 9 * inharmonicity))
                    sample += 0.08 * sin(p0 * 5.0 * (1 + 16 * inharmonicity))
                    sample += 0.04 * sin(p0 * 6.0 * (1 + 25 * inharmonicity))
                } else { // pure
                    sample += sin(p0)
                }
                p0 += inc0
                if p0 > twoPi { p0 -= twoPi }
            }

            // Voice 1 (5th or 3rd)
            if voices >= 2 {
                if mode == 1 {
                    sample += sin(p1)
                    sample += 0.5 * sin(p1 * 0.5)
                    sample += 0.25 * sin(p1 * 1.5)
                    sample += 0.3 * sin(p1 * detuneFactor)
                    sample += 0.15 * sin(p1 * 3.0)
                    sample += 0.08 * sin(p1 * 5.0)
                } else if mode == 2 {
                    sample += sin(p1)
                    sample += 0.35 * sin(p1 * chorusFactor)
                    sample += 0.4  * sin(p1 * 2.0 * (1 + inharmonicity))
                    sample += 0.3  * sin(p1 * 3.0 * (1 + 4 * inharmonicity))
                    sample += 0.15 * sin(p1 * 4.0 * (1 + 9 * inharmonicity))
                    sample += 0.08 * sin(p1 * 5.0 * (1 + 16 * inharmonicity))
                    sample += 0.04 * sin(p1 * 6.0 * (1 + 25 * inharmonicity))
                } else {
                    sample += sin(p1)
                }
                p1 += inc1
                if p1 > twoPi { p1 -= twoPi }
            }

            // Voice 2 (5th in triads)
            if voices >= 3 {
                if mode == 1 {
                    sample += sin(p2)
                    sample += 0.5 * sin(p2 * 0.5)
                    sample += 0.25 * sin(p2 * 1.5)
                    sample += 0.3 * sin(p2 * detuneFactor)
                    sample += 0.15 * sin(p2 * 3.0)
                    sample += 0.08 * sin(p2 * 5.0)
                } else if mode == 2 {
                    sample += sin(p2)
                    sample += 0.35 * sin(p2 * chorusFactor)
                    sample += 0.4  * sin(p2 * 2.0 * (1 + inharmonicity))
                    sample += 0.3  * sin(p2 * 3.0 * (1 + 4 * inharmonicity))
                    sample += 0.15 * sin(p2 * 4.0 * (1 + 9 * inharmonicity))
                    sample += 0.08 * sin(p2 * 5.0 * (1 + 16 * inharmonicity))
                    sample += 0.04 * sin(p2 * 6.0 * (1 + 25 * inharmonicity))
                } else {
                    sample += sin(p2)
                }
                p2 += inc2
                if p2 > twoPi { p2 -= twoPi }
            }

            // Advance warm phases (always, to avoid click on toggle)
            var warmSample: Double = 0
            if voices >= 1 {
                warmSample += sin(wp0)
                wp0 += wInc0
                if wp0 > twoPi { wp0 -= twoPi }
            }
            if voices >= 2 {
                warmSample += sin(wp1)
                wp1 += wInc1
                if wp1 > twoPi { wp1 -= twoPi }
            }
            if voices >= 3 {
                warmSample += sin(wp2)
                wp2 += wInc2
                if wp2 > twoPi { wp2 -= twoPi }
            }

            // Normalize (account for additional harmonic energy in rich/piano mode)
            let vCount = Double(max(voices, 1))
            let normalizer: Double
            switch mode {
            case 1:  normalizer = vCount * 2.28  // rich
            case 2:  normalizer = vCount * 2.32  // piano
            default: normalizer = vCount         // pure
            }
            sample /= normalizer

            // Mix warm detuned oscillator AFTER normalizer so it isn't crushed
            sample += (warmSample / vCount) * Double(warmGainVal)

            // Apply 1-pole LPF in rich/piano mode to soften harsh high partials
            var outSample = Float(sample)
            if mode == 1 {
                lpfState = lpfAlphaRich * outSample + (1.0 - lpfAlphaRich) * lpfState
                outSample = lpfState
            } else if mode == 2 {
                lpfState = lpfAlphaPiano * outSample + (1.0 - lpfAlphaPiano) * lpfState
                outSample = lpfState
            }

            // Amplitude LFO: ±2 dB pulsing, synced with metronome beat
            let lfoMod = Float(1.0 + 0.26 * sin(lfoPhase))
            lfoPhase += lfoInc
            if lfoPhase > twoPi { lfoPhase -= twoPi }

            // Fade envelope
            if fadeGain < targetGain {
                fadeGain = min(fadeGain + fadeInc, targetGain)
            } else if fadeGain > targetGain {
                fadeGain = max(fadeGain - fadeInc, targetGain)
            }

            buf[i] = outSample * vol * fadeGain * lfoMod
        }

        // Write back render-thread-owned state
        state.phase0 = p0
        state.phase1 = p1
        state.phase2 = p2
        state.warmPhase0 = wp0
        state.warmPhase1 = wp1
        state.warmPhase2 = wp2
        state.fadeGain = fadeGain
        state.lfoPhase = lfoPhase
        state.lpfState = lpfState

        return noErr
    }
}

// MARK: - Playback Timestamp (shared with PitchDetector)

/// Shared timestamp of the last audio playback (click or sound cue).
/// PitchDetector reads this to blank analysis during the acoustic echo
/// window, preventing speaker-to-mic feedback from being detected as notes.
/// CFAbsoluteTime (Double) is naturally atomic on ARM64 (8-byte aligned).
final class PlaybackTimestamp: @unchecked Sendable {
    private var _lock = os_unfair_lock()
    private var _value: CFAbsoluteTime = 0

    func set(_ time: CFAbsoluteTime) {
        os_unfair_lock_lock(&_lock)
        _value = time
        os_unfair_lock_unlock(&_lock)
    }

    func get() -> CFAbsoluteTime {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return _value
    }
}

// MARK: - MetroDroneEngine

@MainActor
final class MetroDroneEngine {

    // MARK: Singleton

    static let shared = MetroDroneEngine()

    /// Timestamp of the last click/cue playback. PitchDetector reads this on
    /// the audio thread to suppress detection during the acoustic echo window.
    static let lastPlaybackTime = PlaybackTimestamp()

    // MARK: Published State

    private(set) var currentBeat: Int = 0
    private(set) var isMetronomePlaying = false
    private(set) var isDronePlaying = false

    /// Callback fired on each beat so the VM can publish UI updates.
    /// @MainActor so it runs synchronously in the metronome Task
    /// (avoids stale beats arriving via deferred dispatch after restarts).
    var onBeat: (@MainActor (Int) -> Void)?

    // MARK: Audio Graph

    private var engine: AVAudioEngine?
    private var clickPlayer: AVAudioPlayerNode?
    private var cuePlayer: AVAudioPlayerNode?
    private var droneSourceNode: AVAudioSourceNode?
    private var droneMixer: AVAudioMixerNode?
    private var droneReverb: AVAudioUnitReverb?

    // MARK: Click Buffers

    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?
    private var subClickBuffer: AVAudioPCMBuffer?

    // MARK: Sound Cue Buffers

    private var correctCueBuffer: AVAudioPCMBuffer?
    private var incorrectCueBuffer: AVAudioPCMBuffer?

    private static let sampleRate: Double = 44_100

    // MARK: Metronome Scheduling

    private var metronomeTask: Task<Void, Never>?

    // MARK: Drone State

    /// Shared mutable state for the drone render callback.
    ///
    /// Uses fixed-size scalar fields instead of arrays so that every
    /// read/write is naturally atomic on ARM64. No locks needed.
    ///
    /// - Config fields (written by main thread): freq0/1/2, voiceCount,
    ///   volume, soundMode, isPlaying, targetFadeGain, needsPhaseReset
    /// - Render fields (written by audio thread): phase0/1/2, fadeGain,
    ///   lfoPhase, lpfState
    final class DroneState: @unchecked Sendable {
        // Config — written by main thread
        var freq0: Double = 0
        var freq1: Double = 0
        var freq2: Double = 0
        var voiceCount: Int = 0
        var volume: Float = 0.5
        /// 0 = pure, 1 = rich, 2 = piano
        var soundMode: Int = 1
        var isPlaying: Bool = false
        var targetFadeGain: Float = 0.0
        var needsPhaseReset: Bool = false
        /// LFO rate in Hz. Default 1.5 Hz (free-running).
        /// Set to BPM/60 when metronome is playing to sync the LFO
        /// amplitude wobble with the beat.
        var lfoRateHz: Double = 0.9
        /// When true, the render block resets lfoPhase to 0 so the
        /// LFO peak aligns with the metronome beat.
        var needsLFOPhaseReset: Bool = false

        // Warm effect — always on
        var warmGain: Float = 0.45  // mix level for detuned oscillator (relative to dry)

        // Render — written by audio thread only
        var phase0: Double = 0
        var phase1: Double = 0
        var phase2: Double = 0
        var fadeGain: Float = 0.0
        var lfoPhase: Double = 0
        var lpfState: Float = 0
        // Warm detuned oscillator phases (audio thread only)
        var warmPhase0: Double = 0
        var warmPhase1: Double = 0
        var warmPhase2: Double = 0

        // 50ms fade at 44100 Hz
        let fadeIncrement: Float = 1.0 / Float(44_100.0 * 0.05)
    }

    private let droneState = DroneState()

    // MARK: - Init

    private init() {}

    // MARK: - Engine Lifecycle

    private var sessionIsActive = false

    private func activateSessionIfNeeded() {
        guard !sessionIsActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            sessionIsActive = true
        } catch {
            logger.error("Failed to activate audio session: \(error)")
        }
    }

    @discardableResult
    private func ensureEngine() throws -> AVAudioEngine {
        if let eng = engine { return eng }

        activateSessionIfNeeded()

        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let cue = AVAudioPlayerNode()
        eng.attach(player)
        eng.attach(cue)

        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        eng.connect(player, to: eng.mainMixerNode, format: monoFormat)
        eng.connect(cue, to: eng.mainMixerNode, format: monoFormat)

        // Build drone source node — render block is a free function to avoid @MainActor isolation
        let renderBlock = droneRenderBlock(state: droneState, sampleRate: Self.sampleRate)
        let srcNode = AVAudioSourceNode(format: monoFormat, renderBlock: renderBlock)
        eng.attach(srcNode)

        // Drone sub-mixer + reverb: srcNode → droneMixer → droneReverb → mainMixer
        let mixer = AVAudioMixerNode()
        eng.attach(mixer)
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 25  // subtle room ambience, always on
        eng.attach(reverb)
        eng.connect(srcNode, to: mixer, format: monoFormat)
        eng.connect(mixer, to: reverb, format: monoFormat)
        eng.connect(reverb, to: eng.mainMixerNode, format: monoFormat)

        self.engine = eng
        self.clickPlayer = player
        self.cuePlayer = cue
        self.droneSourceNode = srcNode
        self.droneMixer = mixer
        self.droneReverb = reverb

        // Build click buffers (noise + tonal synthesis)
        accentBuffer = makeClickBuffer(
            toneFreq: 1400, noiseFreq: 2800,
            toneAmp: 0.8, noiseAmp: 0.6,
            mixAmp: 2.8, format: monoFormat
        )
        normalBuffer = makeClickBuffer(
            toneFreq: 900, noiseFreq: 2000,
            toneAmp: 0.7, noiseAmp: 0.5,
            mixAmp: 2.2, format: monoFormat
        )
        subClickBuffer = makeClickBuffer(
            toneFreq: 1200, noiseFreq: 2400,
            toneAmp: 0.55, noiseAmp: 0.40,
            mixAmp: 1.8, format: monoFormat
        )

        // Build sound cue buffers
        correctCueBuffer = makeCorrectCueBuffer(format: monoFormat)
        incorrectCueBuffer = makeIncorrectCueBuffer(format: monoFormat)

        // Route change handling
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in
                self?.handleRouteChange()
            }
        }

        try eng.start()
        player.play()
        cue.play()

        logger.debug("MetroDroneEngine started")
        return eng
    }

    private func handleRouteChange() {
        let wasMetronomePlaying = isMetronomePlaying
        let wasDronePlaying = isDronePlaying
        guard wasMetronomePlaying || wasDronePlaying else { return }

        logger.info("Audio route changed — restarting engine")

        // Tear down current engine
        metronomeTask?.cancel()
        metronomeTask = nil
        clickPlayer?.stop()
        cuePlayer?.stop()
        engine?.stop()
        if let srcNode = droneSourceNode { engine?.detach(srcNode) }
        if let mixer = droneMixer { engine?.detach(mixer) }
        if let reverb = droneReverb { engine?.detach(reverb) }
        if let player = clickPlayer { engine?.detach(player) }
        if let cue = cuePlayer { engine?.detach(cue) }
        engine = nil
        clickPlayer = nil
        cuePlayer = nil
        droneSourceNode = nil
        droneMixer = nil
        droneReverb = nil
        accentBuffer = nil
        normalBuffer = nil
        subClickBuffer = nil
        correctCueBuffer = nil
        incorrectCueBuffer = nil
        sessionIsActive = false

        // Restart — will recreate engine via ensureEngine in startMetronome
        if wasMetronomePlaying {
            startMetronome(bpm: metronomeBPM,
                           timeSignature: TimeSignature(beats: metronomeBeatTotal, noteValue: 4),
                           accents: metronomeAccents,
                           volume: metronomeVolume,
                           subdivision: metronomeSubdivision)
        } else {
            do { try ensureEngine() } catch {
                logger.error("Failed to restart engine after route change: \(error)")
            }
        }
    }

    private func teardownEngineIfIdle() {
        guard !isMetronomePlaying, !isDronePlaying else { return }
        metronomeTask?.cancel()
        metronomeTask = nil
        clickPlayer?.stop()
        cuePlayer?.stop()
        engine?.stop()
        if let srcNode = droneSourceNode { engine?.detach(srcNode) }
        if let mixer = droneMixer { engine?.detach(mixer) }
        if let reverb = droneReverb { engine?.detach(reverb) }
        if let player = clickPlayer { engine?.detach(player) }
        if let cue = cuePlayer { engine?.detach(cue) }
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        engine = nil
        clickPlayer = nil
        cuePlayer = nil
        droneSourceNode = nil
        droneMixer = nil
        droneReverb = nil
        accentBuffer = nil
        normalBuffer = nil
        subClickBuffer = nil
        correctCueBuffer = nil
        incorrectCueBuffer = nil
        sessionIsActive = false
        logger.debug("MetroDroneEngine torn down")
    }

    // MARK: - Metronome

    // Stored for route-change recovery
    private var metronomeBPM: Double = 120
    private var metronomeAccents: [BeatAccent] = []
    private var metronomeBeatTotal: Int = 4
    private var metronomeVolume: Float = 0.7
    private var metronomeSubdivision: NoteSubdivision = .quarter

    func startMetronome(
        bpm: Double,
        timeSignature: TimeSignature,
        accents: [BeatAccent],
        volume: Float,
        subdivision: NoteSubdivision = .quarter,
        delayFirstBeat: Bool = false,
        startingBeat: Int? = nil
    ) {
        // Cancel previous scheduling task without tearing down the engine.
        metronomeTask?.cancel()
        metronomeTask = nil

        do {
            try ensureEngine()
        } catch {
            logger.error("Failed to start engine for metronome: \(error)")
            return
        }

        isMetronomePlaying = true
        if startingBeat == nil {
            currentBeat = 0
        }
        clickPlayer?.volume = volume

        // Store for route-change recovery
        metronomeBPM = bpm
        metronomeBeatTotal = timeSignature.beats
        metronomeAccents = accents
        metronomeVolume = volume
        metronomeSubdivision = subdivision

        let beatCount = timeSignature.beats
        let interval = 60.0 / bpm
        let subCount = subdivision.count

        let initialBeat = startingBeat ?? 0
        metronomeTask = Task { [weak self] in
            // When restarting, wait one full beat interval before the first
            // click to avoid doubling up with the old task's final beat.
            // Using the full interval (not subInterval) ensures the new
            // tempo starts on a proper downbeat regardless of subdivision.
            if delayFirstBeat {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
            }
            var beat = initialBeat
            var subBeat = 0
            while !Task.isCancelled {
                guard let self else { return }
                if subBeat == 0 {
                    // Main beat click
                    let accent = beat < accents.count ? accents[beat] : .normal
                    self.scheduleClick(accent: accent)
                    self.currentBeat = beat
                    self.onBeat?(beat)
                } else {
                    // Sub-beat click (quieter)
                    self.scheduleSubClick()
                }
                subBeat += 1
                if subBeat >= subCount {
                    subBeat = 0
                    beat = (beat + 1) % beatCount
                }
                // Read BPM dynamically so speed trainer tempo changes
                // take effect without restarting (and losing sub-beats).
                let currentSubInterval = (60.0 / self.metronomeBPM) / Double(subCount)
                try? await Task.sleep(for: .seconds(currentSubInterval))
            }
        }
    }

    private func scheduleClick(accent: BeatAccent) {
        guard let player = clickPlayer else { return }
        switch accent {
        case .accent:
            if let buf = accentBuffer {
                player.scheduleBuffer(buf, completionHandler: nil)
                Self.lastPlaybackTime.set(CFAbsoluteTimeGetCurrent())
            }
        case .normal:
            if let buf = normalBuffer {
                player.scheduleBuffer(buf, completionHandler: nil)
                Self.lastPlaybackTime.set(CFAbsoluteTimeGetCurrent())
            }
        case .muted:
            break
        }
    }

    private func scheduleSubClick() {
        guard let player = clickPlayer, let buf = subClickBuffer else { return }
        player.scheduleBuffer(buf, completionHandler: nil)
        // Sub-clicks are too quiet to cause mic echo — no lastPlaybackTime update.
    }

    func stopMetronome() {
        metronomeTask?.cancel()
        metronomeTask = nil
        isMetronomePlaying = false
        currentBeat = 0
        teardownEngineIfIdle()
    }

    func updateMetronomeTempo(bpm: Double, timeSignature: TimeSignature, accents: [BeatAccent], volume: Float, subdivision: NoteSubdivision = .quarter) {
        guard isMetronomePlaying else { return }
        startMetronome(bpm: bpm, timeSignature: timeSignature, accents: accents, volume: volume, subdivision: subdivision, delayFirstBeat: true)
    }

    /// Update BPM without restarting the scheduling loop. The loop reads
    /// `metronomeBPM` dynamically, so the new tempo takes effect on the
    /// next sleep cycle — no sub-beats are lost.
    func updateMetronomeBPM(_ bpm: Double) {
        metronomeBPM = bpm
    }

    func updateMetronomeVolume(_ volume: Float) {
        clickPlayer?.volume = volume
    }

    // MARK: - Countdown Tick

    /// Plays a single countdown tick (used by quiz timer, not the full metronome).
    func playCountdownTick(volume: Float) {
        do {
            try ensureEngine()
        } catch {
            logger.error("Failed to start engine for countdown tick: \(error)")
            return
        }
        guard let player = clickPlayer, let buf = normalBuffer else { return }
        player.volume = volume
        player.scheduleBuffer(buf, completionHandler: nil)
        Self.lastPlaybackTime.set(CFAbsoluteTimeGetCurrent())
    }

    // MARK: - Sound Cues

    func playSoundCue(_ cue: SoundCue, volume: Float) {
        do {
            try ensureEngine()
        } catch {
            logger.error("Failed to start engine for sound cue: \(error)")
            return
        }
        let buffer = (cue == .correct) ? correctCueBuffer : incorrectCueBuffer
        guard let buf = buffer, let player = cuePlayer else { return }
        player.volume = volume
        player.scheduleBuffer(buf, completionHandler: nil)
        Self.lastPlaybackTime.set(CFAbsoluteTimeGetCurrent())
    }

    // MARK: - Drone

    func startDrone(
        key: MusicalNote,
        octave: Int,
        voicing: DroneVoicing,
        sound: DroneSound,
        volume: Float
    ) {
        do {
            try ensureEngine()
        } catch {
            logger.error("Failed to start engine for drone: \(error)")
            return
        }

        applyDroneConfig(key: key, octave: octave, voicing: voicing, sound: sound, volume: volume, resetPhases: true)
        droneState.isPlaying = true
        droneState.targetFadeGain = 1.0

        isDronePlaying = true
    }

    func stopDrone() {
        droneState.targetFadeGain = 0.0
        droneState.isPlaying = false
        isDronePlaying = false

        // Give fade-out time before tearing down
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            self?.teardownEngineIfIdle()
        }
    }

    func updateDrone(
        key: MusicalNote,
        octave: Int,
        voicing: DroneVoicing,
        sound: DroneSound,
        volume: Float
    ) {
        guard isDronePlaying else { return }
        // Crossfade: fade out → apply new config → fade back in
        // This eliminates clicks/pops when switching voicing or sound
        droneState.targetFadeGain = 0.0
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self else { return }
            let resetPhases = voicing.intervals.count != self.droneState.voiceCount
            self.applyDroneConfig(key: key, octave: octave, voicing: voicing, sound: sound,
                                  volume: volume, resetPhases: resetPhases)
            self.droneState.targetFadeGain = 1.0
        }
    }

    func updateDroneVolume(_ volume: Float) {
        droneState.volume = volume
    }

    /// Update the drone LFO rate. When the metronome is playing, pass
    /// `bpm / 60.0` so the LFO wobble syncs with the beat. When the
    /// metronome stops, pass `nil` to revert to the default 1.5 Hz.
    func updateDroneLFORate(bpm: Double?) {
        droneState.lfoRateHz = bpm.map { $0 / 60.0 } ?? 0.9
        // Reset phase so LFO peak aligns with the beat
        if bpm != nil {
            droneState.needsLFOPhaseReset = true
        }
    }

    // MARK: - Private Helpers

    /// Write drone config to the shared state using only scalar fields.
    /// The audio thread will pick up changes on the next render callback.
    private func applyDroneConfig(
        key: MusicalNote,
        octave: Int,
        voicing: DroneVoicing,
        sound: DroneSound,
        volume: Float,
        resetPhases: Bool
    ) {
        let baseFreq = frequencyForNote(key, octave: octave)
        let intervals = voicing.intervals

        droneState.freq0 = intervals.count > 0 ? baseFreq * pow(2.0, Double(intervals[0]) / 12.0) : 0
        droneState.freq1 = intervals.count > 1 ? baseFreq * pow(2.0, Double(intervals[1]) / 12.0) : 0
        droneState.freq2 = intervals.count > 2 ? baseFreq * pow(2.0, Double(intervals[2]) / 12.0) : 0
        droneState.voiceCount = intervals.count
        droneState.soundMode = sound == .pure ? 0 : sound == .rich ? 1 : 2
        droneState.volume = volume

        if resetPhases {
            droneState.needsPhaseReset = true
        }
    }

    // MARK: - Click Buffer Synthesis

    /// Synthesises a percussive click with noise transient + tonal body.
    /// Total duration: 25ms. The noise transient gives a "wood block snap"
    /// that pure sine clicks lack.
    private func makeClickBuffer(
        toneFreq: Double,
        noiseFreq: Double,
        toneAmp: Double,
        noiseAmp: Double,
        mixAmp: Double,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let duration = 0.025 // 25ms
        let frameCount = AVAudioFrameCount(Self.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        let noiseTau = 0.0012  // 1.2ms decay
        let toneTau = 0.005    // 5ms decay

        for i in 0..<Int(frameCount) {
            let t = Double(i) / Self.sampleRate

            // Noise burst: white noise AM-shaped by noiseFreq sine, fast decay
            let noise = Double.random(in: -1...1)
            let noiseEnvelope = exp(-t / noiseTau)
            let noiseAM = sin(2.0 * .pi * noiseFreq * t)
            let noiseSample = noise * noiseAM * noiseEnvelope * noiseAmp

            // Tonal body: sine wave with exponential decay
            let toneEnvelope = exp(-t / toneTau)
            let toneSample = sin(2.0 * .pi * toneFreq * t) * toneEnvelope * toneAmp

            channelData[i] = Float((noiseSample + toneSample) * mixAmp)
        }
        return buffer
    }

    // MARK: - Sound Cue Synthesis

    /// Rising major third: C5 → E5, two sequential 50ms tones.
    private func makeCorrectCueBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let tone1Freq = 523.25  // C5
        let tone2Freq = 659.25  // E5
        let tone1Dur = 0.050    // 50ms
        let tone2Dur = 0.050    // 50ms
        let totalFrames = AVAudioFrameCount(Self.sampleRate * (tone1Dur + tone2Dur))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames
        guard let data = buffer.floatChannelData?[0] else { return nil }

        let amp: Float = 0.6
        let attackMs = 0.005
        let releaseMs = 0.010
        let tone1Frames = Int(Self.sampleRate * tone1Dur)
        let tone2Frames = Int(Self.sampleRate * tone2Dur)

        for i in 0..<tone1Frames {
            let t = Double(i) / Self.sampleRate
            let env = toneEnvelope(t: t, duration: tone1Dur, attack: attackMs, release: releaseMs)
            data[i] = Float(sin(2.0 * .pi * tone1Freq * t) * env) * amp
        }
        for i in 0..<tone2Frames {
            let t = Double(i) / Self.sampleRate
            let env = toneEnvelope(t: t, duration: tone2Dur, attack: attackMs, release: releaseMs)
            data[tone1Frames + i] = Float(sin(2.0 * .pi * tone2Freq * t) * env) * amp
        }
        return buffer
    }

    /// Descending minor second: B4 → Bb4, two sequential tones (60ms + 80ms).
    private func makeIncorrectCueBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let tone1Freq = 493.88  // B4
        let tone2Freq = 466.16  // Bb4
        let tone1Dur = 0.060    // 60ms
        let tone2Dur = 0.080    // 80ms
        let totalFrames = AVAudioFrameCount(Self.sampleRate * (tone1Dur + tone2Dur))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames
        guard let data = buffer.floatChannelData?[0] else { return nil }

        let amp: Float = 0.5
        let attackMs = 0.005
        let releaseMs = 0.010
        let tone1Frames = Int(Self.sampleRate * tone1Dur)
        let tone2Frames = Int(Self.sampleRate * tone2Dur)

        for i in 0..<tone1Frames {
            let t = Double(i) / Self.sampleRate
            let env = toneEnvelope(t: t, duration: tone1Dur, attack: attackMs, release: releaseMs)
            data[i] = Float(sin(2.0 * .pi * tone1Freq * t) * env) * amp
        }
        for i in 0..<tone2Frames {
            let t = Double(i) / Self.sampleRate
            let env = toneEnvelope(t: t, duration: tone2Dur, attack: attackMs, release: releaseMs)
            data[tone1Frames + i] = Float(sin(2.0 * .pi * tone2Freq * t) * env) * amp
        }
        return buffer
    }

    /// Simple attack-sustain-release envelope for cue tones.
    private func toneEnvelope(t: Double, duration: Double, attack: Double, release: Double) -> Double {
        if t < attack {
            return t / attack
        } else if t > duration - release {
            return max(0, (duration - t) / release)
        }
        return 1.0
    }

    /// Compute the frequency in Hz for a given note and octave.
    /// Uses A4 = 440 Hz as reference (MIDI note 69).
    private func frequencyForNote(_ note: MusicalNote, octave: Int) -> Double {
        let midiNote = (octave + 1) * 12 + note.rawValue
        return 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }
}
