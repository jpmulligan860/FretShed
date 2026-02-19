// MetroDroneViewModel.swift
// FretMaster — MetroDrone Feature
//
// @Observable view model bridging MetroDroneEngine to the SwiftUI layer.
// Handles tap tempo, speed trainer state machine, accent management, and
// persistence of all settings via UserDefaults.
//
// NOTE: @Observable + didSet self-assignment (e.g. `x = x.clamped(...)`)
// causes re-entrant withMutation calls that crash under Swift 6 strict
// concurrency. All properties use explicit setter methods instead.

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretmaster", category: "MetroDroneVM")

// MARK: - Speed Trainer Mode

enum SpeedTrainerEndMode: String, CaseIterable, Sendable {
    case stopAtEnd  = "stopAtEnd"
    case loopAtEnd  = "loopAtEnd"

    var label: String {
        switch self {
        case .stopAtEnd: return "Stop at End"
        case .loopAtEnd: return "Loop"
        }
    }
}

// MARK: - MetroDroneViewModel

@Observable
@MainActor
final class MetroDroneViewModel {

    // MARK: Metronome Settings

    var bpm: Double = 120 {
        didSet {
            saveSetting(bpm, forKey: Keys.bpm)
            if engine.isMetronomePlaying && !isSpeedTrainerActive {
                restartMetronome()
            }
        }
    }

    // NOTE: timeSignature and accents didSet blocks ONLY persist.
    // Engine calls and accent adjustment happen in explicit methods
    // (setTimeSignature, cycleAccent) to avoid nested @Observable
    // withMutation crashes.

    var timeSignature: TimeSignature = .fourFour {
        didSet {
            saveSetting(timeSignature.beats, forKey: Keys.timeSigBeats)
            saveSetting(timeSignature.noteValue, forKey: Keys.timeSigNoteValue)
        }
    }

    var accents: [BeatAccent] = [.accent, .normal, .normal, .normal] {
        didSet {
            let raw = accents.map(\.rawValue).joined(separator: ",")
            saveSetting(raw, forKey: Keys.accentsRaw)
        }
    }

    var metronomeVolume: Float = 0.7 {
        didSet {
            saveSetting(metronomeVolume, forKey: Keys.metronomeVolume)
            engine.updateMetronomeVolume(metronomeVolume)
        }
    }

    // MARK: Drone Settings

    var droneKey: MusicalNote = .a {
        didSet {
            saveSetting(droneKey.rawValue, forKey: Keys.droneKey)
            if engine.isDronePlaying { updateDrone() }
        }
    }

    var droneOctave: Int = 3 {
        didSet {
            saveSetting(droneOctave, forKey: Keys.droneOctave)
            if engine.isDronePlaying { updateDrone() }
        }
    }

    var droneVoicing: DroneVoicing = .root {
        didSet {
            saveSetting(droneVoicing.rawValue, forKey: Keys.droneVoicing)
            if engine.isDronePlaying { updateDrone() }
        }
    }

    var droneSound: DroneSound = .rich {
        didSet {
            saveSetting(droneSound.rawValue, forKey: Keys.droneSound)
            if engine.isDronePlaying { updateDrone() }
        }
    }

    var droneVolume: Float = 0.5 {
        didSet {
            saveSetting(droneVolume, forKey: Keys.droneVolume)
            engine.updateDroneVolume(droneVolume)
        }
    }

    // MARK: Speed Trainer Settings

    var speedTrainerStartBPM: Double = 80 {
        didSet { saveSetting(speedTrainerStartBPM, forKey: Keys.stStartBPM) }
    }

    var speedTrainerEndBPM: Double = 120 {
        didSet { saveSetting(speedTrainerEndBPM, forKey: Keys.stEndBPM) }
    }

    var speedTrainerIncrement: Double = 5 {
        didSet { saveSetting(speedTrainerIncrement, forKey: Keys.stIncrement) }
    }

    var speedTrainerBarsPerStep: Int = 4 {
        didSet { saveSetting(speedTrainerBarsPerStep, forKey: Keys.stBarsPerStep) }
    }

    var speedTrainerRepsPerStep: Int = 1 {
        didSet { saveSetting(speedTrainerRepsPerStep, forKey: Keys.stRepsPerStep) }
    }

    var speedTrainerEndMode: SpeedTrainerEndMode = .stopAtEnd {
        didSet {
            saveSetting(speedTrainerEndMode == .loopAtEnd, forKey: Keys.stLoopAtEnd)
        }
    }

    // MARK: Count-In Settings

    var countInBars: Int = 0 {
        didSet { saveSetting(countInBars, forKey: Keys.countInBars) }
    }

    // MARK: Play State (read-only for UI)

    private(set) var isMetronomePlaying = false
    private(set) var isDronePlaying = false
    private(set) var currentBeat: Int = 0
    private(set) var isSpeedTrainerActive = false
    private(set) var currentTrainerBPM: Double = 0
    private(set) var isCountingIn = false
    private(set) var countInBarsRemaining: Int = 0

    // MARK: Tap Tempo

    private var tapTimestamps: [Date] = []

    // MARK: Speed Trainer Internal

    private var trainerBarBeatCount = 0
    private var trainerBarCount = 0
    private var trainerRepCount = 0

    // MARK: Count-In Internal

    private var countInBeatCount = 0
    private var countInBarCount = 0

    // MARK: Private

    private let engine = MetroDroneEngine.shared
    private let defaults = UserDefaults.standard

    // MARK: - Init

    init() {
        loadSettings()
    }

    // MARK: - Metronome Controls

    func toggleMetronome() {
        if isMetronomePlaying {
            stopMetronome()
        } else {
            startMetronome()
        }
    }

    func startMetronome() {
        if countInBars > 0 {
            isCountingIn = true
            countInBeatCount = 0
            countInBarCount = 0
            countInBarsRemaining = countInBars
        }
        engine.onBeat = { [weak self] beat in
            self?.handleBeat(beat)
        }
        engine.startMetronome(
            bpm: bpm,
            timeSignature: timeSignature,
            accents: accents,
            volume: metronomeVolume
        )
        isMetronomePlaying = true
    }

    func stopMetronome() {
        engine.stopMetronome()
        engine.onBeat = nil
        isMetronomePlaying = false
        currentBeat = 0
        isCountingIn = false
        countInBeatCount = 0
        countInBarCount = 0
        countInBarsRemaining = 0
        if isSpeedTrainerActive {
            stopSpeedTrainer()
        }
    }

    // MARK: - Drone Controls

    func toggleDrone() {
        if isDronePlaying {
            stopDrone()
        } else {
            startDrone()
        }
    }

    func startDrone() {
        engine.startDrone(
            key: droneKey,
            octave: droneOctave,
            voicing: droneVoicing,
            sound: droneSound,
            volume: droneVolume
        )
        isDronePlaying = true
    }

    func stopDrone() {
        engine.stopDrone()
        isDronePlaying = false
    }

    // MARK: - Tap Tempo

    func tapTempo() {
        let now = Date()

        // Reset if gap > 2 seconds
        if let last = tapTimestamps.last, now.timeIntervalSince(last) > 2.0 {
            tapTimestamps.removeAll()
        }

        tapTimestamps.append(now)

        // Keep last 8 taps
        if tapTimestamps.count > 8 {
            tapTimestamps.removeFirst()
        }

        // Need at least 2 taps to compute BPM
        guard tapTimestamps.count >= 2 else { return }

        var totalInterval: TimeInterval = 0
        for i in 1..<tapTimestamps.count {
            totalInterval += tapTimestamps[i].timeIntervalSince(tapTimestamps[i - 1])
        }
        let avgInterval = totalInterval / Double(tapTimestamps.count - 1)
        guard avgInterval > 0 else { return }
        let newBPM = min(max((60.0 / avgInterval), 20), 300)
        bpm = (newBPM * 10).rounded() / 10
    }

    // MARK: - Speed Trainer

    func toggleSpeedTrainer() {
        if isSpeedTrainerActive {
            stopSpeedTrainer()
        } else {
            startSpeedTrainer()
        }
    }

    func startSpeedTrainer() {
        guard speedTrainerStartBPM < speedTrainerEndBPM else { return }

        isSpeedTrainerActive = true
        currentTrainerBPM = speedTrainerStartBPM
        trainerBarBeatCount = 0
        trainerBarCount = 0
        trainerRepCount = 0

        bpm = currentTrainerBPM
        if !isMetronomePlaying {
            startMetronome()
        } else {
            restartMetronome()
        }
    }

    func stopSpeedTrainer() {
        isSpeedTrainerActive = false
        currentTrainerBPM = 0
        trainerBarBeatCount = 0
        trainerBarCount = 0
        trainerRepCount = 0
    }

    // MARK: - Time Signature (explicit method to avoid nested @Observable mutation)

    /// Call this instead of setting `timeSignature` directly.
    /// Setting the property from the view would only persist; this method
    /// also adjusts the accent array and restarts the metronome.
    func setTimeSignature(_ ts: TimeSignature) {
        currentBeat = 0
        timeSignature = ts               // didSet persists only
        adjustAccentsForTimeSignature()   // sets accents (didSet persists only)
        if engine.isMetronomePlaying {
            restartMetronome()
        }
    }

    // MARK: - Accent Toggling

    func cycleAccent(at index: Int) {
        guard index >= 0, index < accents.count else { return }
        accents[index] = accents[index].next
        if engine.isMetronomePlaying {
            restartMetronome()
        }
    }

    // MARK: - Cleanup

    func onDisappear() {
        if isMetronomePlaying { stopMetronome() }
        if isDronePlaying { stopDrone() }
    }

    // MARK: - Private: Beat Handling

    private func handleBeat(_ beat: Int) {
        currentBeat = beat

        // Count-in phase: count beats/bars, skip speed trainer tracking
        if isCountingIn {
            countInBeatCount += 1
            if countInBeatCount >= timeSignature.beats {
                countInBeatCount = 0
                countInBarCount += 1
                countInBarsRemaining = max(countInBars - countInBarCount, 0)
                if countInBarCount >= countInBars {
                    isCountingIn = false
                    countInBarsRemaining = 0
                }
            }
            return
        }

        guard isSpeedTrainerActive else { return }

        trainerBarBeatCount += 1

        if trainerBarBeatCount >= timeSignature.beats {
            trainerBarBeatCount = 0
            trainerBarCount += 1

            if trainerBarCount >= speedTrainerBarsPerStep {
                trainerBarCount = 0
                trainerRepCount += 1

                if trainerRepCount >= speedTrainerRepsPerStep {
                    trainerRepCount = 0
                    advanceTrainerTempo()
                }
            }
        }
    }

    private func advanceTrainerTempo() {
        let nextBPM = currentTrainerBPM + speedTrainerIncrement

        if nextBPM > speedTrainerEndBPM {
            if speedTrainerEndMode == .loopAtEnd {
                currentTrainerBPM = speedTrainerStartBPM
                bpm = currentTrainerBPM
                restartMetronome()
            } else {
                stopSpeedTrainer()
                stopMetronome()
            }
        } else {
            currentTrainerBPM = nextBPM
            bpm = currentTrainerBPM
            restartMetronome()
        }
    }

    private func restartMetronome() {
        engine.startMetronome(
            bpm: bpm,
            timeSignature: timeSignature,
            accents: accents,
            volume: metronomeVolume,
            delayFirstBeat: true
        )
    }

    private func updateDrone() {
        engine.updateDrone(
            key: droneKey,
            octave: droneOctave,
            voicing: droneVoicing,
            sound: droneSound,
            volume: droneVolume
        )
    }

    // MARK: - Accent Management

    private func adjustAccentsForTimeSignature() {
        let needed = timeSignature.beats
        if accents.count == needed { return }

        var newAccents = accents
        if newAccents.count < needed {
            newAccents.append(contentsOf: Array(repeating: BeatAccent.normal, count: needed - newAccents.count))
        } else {
            newAccents = Array(newAccents.prefix(needed))
        }
        if !newAccents.isEmpty {
            newAccents[0] = .accent
        }
        accents = newAccents
    }

    // MARK: - Persistence

    private enum Keys {
        static let bpm = "metroDrone.bpm"
        static let timeSigBeats = "metroDrone.timeSigBeats"
        static let timeSigNoteValue = "metroDrone.timeSigNoteValue"
        static let accentsRaw = "metroDrone.accentsRaw"
        static let metronomeVolume = "metroDrone.metronomeVolume"
        static let droneKey = "metroDrone.droneKey"
        static let droneOctave = "metroDrone.droneOctave"
        static let droneVoicing = "metroDrone.droneVoicing"
        static let droneSound = "metroDrone.droneSound"
        static let droneVolume = "metroDrone.droneVolume"
        static let stStartBPM = "metroDrone.stStartBPM"
        static let stEndBPM = "metroDrone.stEndBPM"
        static let stIncrement = "metroDrone.stIncrement"
        static let stBarsPerStep = "metroDrone.stBarsPerStep"
        static let stRepsPerStep = "metroDrone.stRepsPerStep"
        static let stLoopAtEnd = "metroDrone.stLoopAtEnd"
        static let countInBars = "metroDrone.countInBars"
    }

    private func loadSettings() {
        let d = defaults

        if d.object(forKey: Keys.bpm) != nil {
            bpm = d.double(forKey: Keys.bpm)
        }
        if d.object(forKey: Keys.timeSigBeats) != nil {
            let beats = d.integer(forKey: Keys.timeSigBeats)
            let noteValue = d.object(forKey: Keys.timeSigNoteValue) != nil ? d.integer(forKey: Keys.timeSigNoteValue) : 4
            timeSignature = TimeSignature(beats: max(beats, 1), noteValue: max(noteValue, 1))
        }
        if let raw = d.string(forKey: Keys.accentsRaw) {
            let parsed = raw.split(separator: ",").compactMap { BeatAccent(rawValue: String($0)) }
            if !parsed.isEmpty { accents = parsed }
        }
        if d.object(forKey: Keys.metronomeVolume) != nil {
            metronomeVolume = d.float(forKey: Keys.metronomeVolume)
        }
        if d.object(forKey: Keys.droneKey) != nil {
            if let note = MusicalNote(rawValue: d.integer(forKey: Keys.droneKey)) {
                droneKey = note
            }
        }
        if d.object(forKey: Keys.droneOctave) != nil {
            droneOctave = d.integer(forKey: Keys.droneOctave)
        }
        if let raw = d.string(forKey: Keys.droneVoicing), let v = DroneVoicing(rawValue: raw) {
            droneVoicing = v
        }
        if let raw = d.string(forKey: Keys.droneSound), let s = DroneSound(rawValue: raw) {
            droneSound = s
        }
        if d.object(forKey: Keys.droneVolume) != nil {
            droneVolume = d.float(forKey: Keys.droneVolume)
        }
        if d.object(forKey: Keys.stStartBPM) != nil {
            speedTrainerStartBPM = d.double(forKey: Keys.stStartBPM)
        }
        if d.object(forKey: Keys.stEndBPM) != nil {
            speedTrainerEndBPM = d.double(forKey: Keys.stEndBPM)
        }
        if d.object(forKey: Keys.stIncrement) != nil {
            speedTrainerIncrement = d.double(forKey: Keys.stIncrement)
        }
        if d.object(forKey: Keys.stBarsPerStep) != nil {
            speedTrainerBarsPerStep = d.integer(forKey: Keys.stBarsPerStep)
        }
        if d.object(forKey: Keys.stRepsPerStep) != nil {
            speedTrainerRepsPerStep = d.integer(forKey: Keys.stRepsPerStep)
        }
        if d.object(forKey: Keys.stLoopAtEnd) != nil {
            speedTrainerEndMode = d.bool(forKey: Keys.stLoopAtEnd) ? .loopAtEnd : .stopAtEnd
        }
        if d.object(forKey: Keys.countInBars) != nil {
            countInBars = d.integer(forKey: Keys.countInBars)
        }

        adjustAccentsForTimeSignature()
    }

    private func saveSetting<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
