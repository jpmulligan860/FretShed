// MetronomeScheduler.swift
// FretShed — Audio Layer
//
// Sample-accurate metronome scheduling using AVAudioPlayerNode.scheduleBuffer(at:).
// A coarse DispatchSourceTimer (~30ms) keeps a lookahead window filled with
// precisely-timed clicks. Timer jitter does not affect audio timing because
// clicks are queued at exact sample positions before they're needed.
//
// Thread safety: os_unfair_lock protects params (written by main thread,
// read by timer queue). AVAudioPlayerNode.scheduleBuffer(at:) is thread-safe.

import AVFoundation
import Dispatch

// MARK: - MetronomeScheduler

final class MetronomeScheduler: @unchecked Sendable {

    // MARK: - Schedule Parameters (atomically swapped)

    struct Params {
        var samplesPerBeat: Double           // sampleRate * 60.0 / bpm
        var subdivisionCount: Int            // 1, 2, 3, or 4
        var beatsPerMeasure: Int
        var accents: [BeatAccent]
    }

    // MARK: - Callbacks

    /// Fired on main thread when a main beat is about to sound.
    var onBeat: (@MainActor (Int) -> Void)?

    /// Fired with predicted wall-clock time of each click (for echo suppression).
    var onScheduleClick: ((CFAbsoluteTime) -> Void)?

    // MARK: - Private State

    private let clickPlayer: AVAudioPlayerNode
    private let accentBuffer: AVAudioPCMBuffer
    private let normalBuffer: AVAudioPCMBuffer
    private let subClickBuffer: AVAudioPCMBuffer
    private let sampleRate: Double

    private var _lock = os_unfair_lock()
    private var _params: Params
    private var _pendingBPMOnDownbeat: Double?

    // Scheduling position (only accessed on timerQueue)
    private var nextScheduleSample: AVAudioFramePosition = 0
    private var currentBeat: Int = 0
    private var currentSubBeat: Int = 0

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(
        label: "com.jpm.fretshed.metronome-scheduler",
        qos: .userInteractive
    )

    /// Lookahead window in seconds. Clicks are scheduled this far ahead
    /// of the current playback position. Must exceed the timer interval
    /// to guarantee no missed clicks.
    private let lookaheadSeconds: Double = 0.100

    // MARK: - Init

    init(
        clickPlayer: AVAudioPlayerNode,
        accentBuffer: AVAudioPCMBuffer,
        normalBuffer: AVAudioPCMBuffer,
        subClickBuffer: AVAudioPCMBuffer,
        sampleRate: Double,
        bpm: Double,
        timeSignature: TimeSignature,
        accents: [BeatAccent],
        subdivision: NoteSubdivision
    ) {
        self.clickPlayer = clickPlayer
        self.accentBuffer = accentBuffer
        self.normalBuffer = normalBuffer
        self.subClickBuffer = subClickBuffer
        self.sampleRate = sampleRate
        self._params = Params(
            samplesPerBeat: sampleRate * 60.0 / bpm,
            subdivisionCount: subdivision.count,
            beatsPerMeasure: timeSignature.beats,
            accents: accents
        )
    }

    // MARK: - Thread-Safe Param Access

    private var params: Params {
        get {
            os_unfair_lock_lock(&_lock)
            defer { os_unfair_lock_unlock(&_lock) }
            return _params
        }
        set {
            os_unfair_lock_lock(&_lock)
            _params = newValue
            os_unfair_lock_unlock(&_lock)
        }
    }

    private var pendingBPMOnDownbeat: Double? {
        get {
            os_unfair_lock_lock(&_lock)
            defer { os_unfair_lock_unlock(&_lock) }
            return _pendingBPMOnDownbeat
        }
        set {
            os_unfair_lock_lock(&_lock)
            _pendingBPMOnDownbeat = newValue
            os_unfair_lock_unlock(&_lock)
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard let nodeTime = clickPlayer.lastRenderTime,
              let playerTime = clickPlayer.playerTime(forNodeTime: nodeTime) else { return }

        // Start scheduling 10ms in the future to ensure first click isn't in the past
        nextScheduleSample = playerTime.sampleTime + AVAudioFramePosition(sampleRate * 0.010)
        currentBeat = 0
        currentSubBeat = 0

        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now(), repeating: .milliseconds(30), leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.pump() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Seamless Parameter Updates

    func updateBPM(_ bpm: Double) {
        var p = params
        p.samplesPerBeat = sampleRate * 60.0 / bpm
        params = p
    }

    func updateSubdivision(_ sub: NoteSubdivision) {
        timerQueue.async { [self] in
            // Snap to the next main beat boundary to avoid orphaned sub-beats
            let p = params
            let samplesPerSubBeat = p.samplesPerBeat / Double(p.subdivisionCount)
            let remainingSubs = p.subdivisionCount - currentSubBeat
            nextScheduleSample += AVAudioFramePosition(Double(remainingSubs) * samplesPerSubBeat)
            currentSubBeat = 0

            var newParams = p
            newParams.subdivisionCount = sub.count
            params = newParams
        }
    }

    func updateAccents(_ accents: [BeatAccent]) {
        var p = params
        p.accents = accents
        params = p
    }

    func updateTimeSignature(_ ts: TimeSignature, accents: [BeatAccent]) {
        timerQueue.async { [self] in
            var p = params
            p.beatsPerMeasure = ts.beats
            p.accents = accents
            params = p
            // Reset to beat 0 so the new pattern starts cleanly
            currentBeat = 0
            currentSubBeat = 0
        }
    }

    func queueBPMChangeOnDownbeat(_ bpm: Double) {
        pendingBPMOnDownbeat = bpm
    }

    // MARK: - The Pump

    /// Called every ~30ms. Schedules all clicks that fall within the lookahead window.
    private func pump() {
        guard let nodeTime = clickPlayer.lastRenderTime,
              let playerTime = clickPlayer.playerTime(forNodeTime: nodeTime) else { return }

        let currentSample = playerTime.sampleTime
        let lookaheadSamples = AVAudioFramePosition(sampleRate * lookaheadSeconds)
        let horizon = currentSample + lookaheadSamples

        let p = params

        while nextScheduleSample < horizon {
            // Check for pending downbeat BPM change
            if currentBeat == 0 && currentSubBeat == 0 {
                if let newBPM = pendingBPMOnDownbeat {
                    pendingBPMOnDownbeat = nil
                    var updated = p
                    updated.samplesPerBeat = sampleRate * 60.0 / newBPM
                    params = updated
                    // Re-read after update (samplesPerBeat changed)
                    // Fall through — this beat uses the new tempo
                }
            }

            // Re-read params in case downbeat change modified them
            let cp = params
            let samplesPerSubBeat = cp.samplesPerBeat / Double(cp.subdivisionCount)

            let isMainBeat = (currentSubBeat == 0)

            // Select buffer
            let buffer: AVAudioPCMBuffer?
            if isMainBeat {
                let accent = currentBeat < cp.accents.count ? cp.accents[currentBeat] : .normal
                switch accent {
                case .accent: buffer = accentBuffer
                case .normal: buffer = normalBuffer
                case .muted:  buffer = nil
                }
            } else {
                buffer = subClickBuffer
            }

            // Schedule at exact sample position
            if let buf = buffer {
                let time = AVAudioTime(sampleTime: nextScheduleSample, atRate: sampleRate)
                clickPlayer.scheduleBuffer(buf, at: time, completionHandler: nil)

                // Predict wall-clock time for echo suppression
                let sampleOffset = nextScheduleSample - currentSample
                let wallTime = CFAbsoluteTimeGetCurrent() + Double(sampleOffset) / sampleRate
                onScheduleClick?(wallTime)
            }

            // Fire UI callback on main beats, timed to match audio playback
            if isMainBeat {
                let beat = currentBeat
                let fireDelay = max(0, Double(nextScheduleSample - currentSample) / sampleRate)
                DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay) { [weak self] in
                    self?.onBeat?(beat)
                }
            }

            // Advance
            nextScheduleSample += AVAudioFramePosition(samplesPerSubBeat)
            currentSubBeat += 1
            if currentSubBeat >= cp.subdivisionCount {
                currentSubBeat = 0
                currentBeat = (currentBeat + 1) % cp.beatsPerMeasure
            }
        }
    }
}
