// CalibrationEngine.swift
// FretShed — Audio Layer
//
// State machine that orchestrates the audio calibration procedure:
//   .welcome → .measuringNoise → .testingString → .complete
//
// Pattern matches QuizViewModel: @Observable, @MainActor, phases as enum.

import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "CalibrationEngine")

// MARK: - CalibrationPhase

public enum CalibrationPhase: Equatable {
    case welcome
    case measuringNoise(progress: Double)  // 0.0–1.0
    case testingString(number: Int)        // 1–6 (current string being tested)
    case testingFretted(number: Int)       // 1–6 (current string, 12th fret)
    case complete
}

// MARK: - CalibrationEngine

@MainActor
@Observable
public final class CalibrationEngine {

    // MARK: - Public State

    public private(set) var phase: CalibrationPhase = .welcome
    public private(set) var detectedInputSource: AudioInputSource = .unknown
    public private(set) var stringResults: [Int: Bool] = [:]  // string number → passed (open)
    public private(set) var frettedStringResults: [Int: Bool] = [:]  // string number → passed (12th fret)
    public private(set) var measuredNoiseFloor: Float = 0.01
    public private(set) var measuredAGCGain: Float = 2.0
    public private(set) var signalQualityScore: Float = 0.0

    /// The PitchDetector used for calibration. Exposed so the view can
    /// show inputLevel and detectedNote.
    public let detector = PitchDetector()

    /// Whether we're re-calibrating (skip welcome screen).
    public let isRecalibration: Bool

    // MARK: - Private

    private var noiseReadings: [Float] = []
    private var noiseMeasureTask: Task<Void, Never>?
    private var stringTestTask: Task<Void, Never>?

    /// Open string notes for standard tuning, strings 6→1 (low E to high E).
    static let openStringNotes: [(string: Int, note: MusicalNote)] = [
        (6, .e),   // Low E
        (5, .a),   // A
        (4, .d),   // D
        (3, .g),   // G
        (2, .b),   // B
        (1, .e),   // High E
    ]

    /// Display names for each open string.
    static let stringNames: [Int: String] = [
        6: "Low E (6th)",
        5: "A (5th)",
        4: "D (4th)",
        3: "G (3rd)",
        2: "B (2nd)",
        1: "High E (1st)"
    ]

    /// Expected notes at the 12th fret for each string (one octave above open).
    /// Same note names as open strings — the detector matches by note name, not octave.
    static let frettedStringNotes: [(string: Int, note: MusicalNote)] = [
        (6, .e),   // E3 (12th fret of low E)
        (5, .a),   // A3
        (4, .d),   // D4
        (3, .g),   // G4
        (2, .b),   // B4
        (1, .e),   // E5
    ]

    // MARK: - Init

    public init(isRecalibration: Bool = false) {
        self.isRecalibration = isRecalibration
        // Pre-initialise all strings as not-yet-tested
        for s in 1...6 {
            stringResults[s] = false
            frettedStringResults[s] = false
        }
    }

    // MARK: - Input Source Detection

    /// Activates the audio session (if needed) and detects the input source.
    /// Call from the view's `.task` so the welcome screen shows the correct
    /// device name. Safe to call multiple times — only activates once.
    public func detectInputSource() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to activate audio session for input detection: \(error)")
        }
        detectedInputSource = AudioInputSource.detectCurrent()
        logger.info("Detected input source: \(self.detectedInputSource.displayName)")
    }

    // MARK: - Start Silence Measurement

    /// Begins the 3-second silence measurement phase.
    /// Starts the PitchDetector, samples `currentNoiseFloor` every 100ms for 3s (30 readings),
    /// then takes the median and auto-advances to string testing.
    public func startSilenceMeasurement() async {
        // Start detector if not already running
        if !detector.isRunning {
            // Ensure input source is detected before starting the detector,
            // so the tap closure captures the correct input source.
            if detectedInputSource == .unknown {
                detectInputSource()
            }
            detector.calibratedInputSource = detectedInputSource

            do {
                try await detector.start()
            } catch {
                logger.error("Failed to start detector for calibration: \(error)")
                return
            }
        }

        phase = .measuringNoise(progress: 0)
        noiseReadings.removeAll()

        noiseMeasureTask = Task { @MainActor in
            let totalReadings = 30
            let intervalMs = 100

            for i in 0..<totalReadings {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(intervalMs))
                guard !Task.isCancelled else { return }

                let nf = detector.currentNoiseFloor
                noiseReadings.append(nf)
                let progress = Double(i + 1) / Double(totalReadings)
                phase = .measuringNoise(progress: progress)
            }

            // Take median of readings
            let sorted = noiseReadings.sorted()
            measuredNoiseFloor = sorted.isEmpty ? 0.01 : sorted[sorted.count / 2]
            logger.info("Noise floor measured: \(self.measuredNoiseFloor)")

            // Auto-advance to string testing
            startStringTest(stringIndex: 0)
        }
    }

    // MARK: - String Testing

    /// The expected note for the current string being tested (open or fretted).
    public var expectedNote: MusicalNote? {
        switch phase {
        case .testingString(let num):
            return Self.openStringNotes.first(where: { $0.string == num })?.note
        case .testingFretted(let num):
            return Self.frettedStringNotes.first(where: { $0.string == num })?.note
        default:
            return nil
        }
    }

    /// The display name for the current string being tested.
    public var currentStringName: String? {
        switch phase {
        case .testingString(let num), .testingFretted(let num):
            return Self.stringNames[num]
        default:
            return nil
        }
    }

    /// Whether the engine is currently in the fretted (12th fret) test phase.
    public var isFrettedPhase: Bool {
        if case .testingFretted = phase { return true }
        return false
    }

    private func startStringTest(stringIndex: Int) {
        guard stringIndex < Self.openStringNotes.count else {
            // All open strings done — transition to fretted phase
            startFrettedTest(stringIndex: 0)
            return
        }

        let entry = Self.openStringNotes[stringIndex]
        phase = .testingString(number: entry.string)

        stringTestTask?.cancel()
        stringTestTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }

                if detector.detectedNote == entry.note {
                    stringResults[entry.string] = true
                    logger.info("String \(entry.string) open detected: \(entry.note.sharpName)")

                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }

                    startStringTest(stringIndex: stringIndex + 1)
                    return
                }
            }
        }
    }

    // MARK: - Fretted String Testing (12th Fret)

    private func startFrettedTest(stringIndex: Int) {
        guard stringIndex < Self.frettedStringNotes.count else {
            completeCalibration()
            return
        }

        let entry = Self.frettedStringNotes[stringIndex]
        phase = .testingFretted(number: entry.string)

        stringTestTask?.cancel()
        stringTestTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }

                if detector.detectedNote == entry.note {
                    frettedStringResults[entry.string] = true
                    logger.info("String \(entry.string) fret 12 detected: \(entry.note.sharpName)")

                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }

                    startFrettedTest(stringIndex: stringIndex + 1)
                    return
                }
            }
        }
    }

    // MARK: - Complete

    private func completeCalibration() {
        // Capture AGC gain from the detector's current state
        measuredAGCGain = detector.currentAGCGain

        // Quality score: fraction of strings that passed (always 1.0 since all required)
        let passed = stringResults.values.filter { $0 }.count
        signalQualityScore = Float(passed) / 6.0

        phase = .complete
        logger.info("Calibration complete — noise floor: \(self.measuredNoiseFloor), AGC gain: \(self.measuredAGCGain), quality: \(self.signalQualityScore)")
    }

    // MARK: - Build Profile

    /// Creates an `AudioCalibrationProfile` from the collected measurements.
    public func buildProfile() -> AudioCalibrationProfile {
        AudioCalibrationProfile(
            inputSource: detectedInputSource,
            measuredNoiseFloorRMS: measuredNoiseFloor,
            measuredAGCGain: measuredAGCGain,
            signalQualityScore: signalQualityScore,
            stringResults: stringResults,
            frettedStringResults: frettedStringResults
        )
    }

    // MARK: - Cleanup

    public func cancel() {
        noiseMeasureTask?.cancel()
        stringTestTask?.cancel()
        Task { await detector.stop() }
    }
}
