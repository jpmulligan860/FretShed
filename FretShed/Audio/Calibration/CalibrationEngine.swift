// CalibrationEngine.swift
// FretShed — Audio Layer
//
// State machine that orchestrates the audio calibration procedure:
//   .welcome → .measuringNoise → .testingString → .complete
//
// Pattern matches QuizViewModel: @Observable, @MainActor, phases as enum.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "CalibrationEngine")

// MARK: - CalibrationPhase

public enum CalibrationPhase: Equatable {
    case welcome
    case measuringNoise(progress: Double)  // 0.0–1.0
    case testingString(number: Int)        // 1–6 (current string being tested)
    case complete
}

// MARK: - CalibrationEngine

@MainActor
@Observable
public final class CalibrationEngine {

    // MARK: - Public State

    public private(set) var phase: CalibrationPhase = .welcome
    public private(set) var detectedInputSource: AudioInputSource = .unknown
    public private(set) var stringResults: [Int: Bool] = [:]  // string number → passed
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

    // MARK: - Init

    public init(isRecalibration: Bool = false) {
        self.isRecalibration = isRecalibration
        self.detectedInputSource = AudioInputSource.detectCurrent()
        // Pre-initialise all strings as not-yet-tested
        for s in 1...6 { stringResults[s] = false }
    }

    // MARK: - Start Silence Measurement

    /// Begins the 3-second silence measurement phase.
    /// Starts the PitchDetector, samples `currentNoiseFloor` every 100ms for 3s (30 readings),
    /// then takes the median and auto-advances to string testing.
    public func startSilenceMeasurement() async {
        // Start detector if not already running
        if !detector.isRunning {
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

    /// The expected note for the current string being tested.
    public var expectedNote: MusicalNote? {
        guard case .testingString(let num) = phase else { return nil }
        return Self.openStringNotes.first(where: { $0.string == num })?.note
    }

    /// The display name for the current string being tested.
    public var currentStringName: String? {
        guard case .testingString(let num) = phase else { return nil }
        return Self.stringNames[num]
    }

    private func startStringTest(stringIndex: Int) {
        guard stringIndex < Self.openStringNotes.count else {
            completeCalibration()
            return
        }

        let entry = Self.openStringNotes[stringIndex]
        phase = .testingString(number: entry.string)

        stringTestTask?.cancel()
        stringTestTask = Task { @MainActor in
            // Poll detector.detectedNote until the expected note is found
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }

                if detector.detectedNote == entry.note {
                    // Mark this string as passed
                    stringResults[entry.string] = true
                    logger.info("String \(entry.string) detected: \(entry.note.sharpName)")

                    // Brief pause so the user sees the checkmark
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }

                    // Advance to next string
                    startStringTest(stringIndex: stringIndex + 1)
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
            stringResults: stringResults
        )
    }

    // MARK: - Cleanup

    public func cancel() {
        noiseMeasureTask?.cancel()
        stringTestTask?.cancel()
        Task { await detector.stop() }
    }
}
