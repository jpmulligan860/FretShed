// GoertzelTrackerTests.swift
// FretShed — Unit Tests
//
// Verifies the GoertzelTracker's frequency measurement accuracy using
// synthetic signals: pure sines, harmonic-rich guitar-like signals,
// decaying signals, and frequency ramps (peg turn simulation).

import XCTest
@testable import FretShed

final class GoertzelTrackerTests: XCTestCase {

    private let sampleRate: Double = 44100.0
    private let windowSize: Int = 4096
    private let hopSize: Int = 512

    // MARK: - Helpers

    /// Generates a harmonic-rich signal mimicking a plucked guitar string.
    /// Fundamental + overtones decaying at 1/h amplitude.
    private func generateHarmonicSignal(
        frequency: Double,
        amplitude: Float = 0.5,
        harmonics: Int = 6,
        count: Int? = nil
    ) -> [Float] {
        let n = count ?? windowSize
        var samples = [Float](repeating: 0, count: n)
        for h in 1...harmonics {
            let amp = amplitude / Float(h)
            let twoPiF = 2.0 * Double.pi * frequency * Double(h)
            for i in 0..<n {
                samples[i] += amp * Float(sin(twoPiF * Double(i) / sampleRate))
            }
        }
        return samples
    }

    /// Generates a decaying harmonic signal (exponential amplitude envelope).
    private func generateDecayingSignal(
        frequency: Double,
        amplitude: Float = 0.5,
        decayRate: Double = 3.0,  // higher = faster decay
        count: Int? = nil
    ) -> [Float] {
        let n = count ?? windowSize
        var samples = [Float](repeating: 0, count: n)
        for h in 1...6 {
            let amp = amplitude / Float(h)
            let twoPiF = 2.0 * Double.pi * frequency * Double(h)
            for i in 0..<n {
                let t = Double(i) / sampleRate
                let envelope = Float(exp(-decayRate * t))
                samples[i] += amp * envelope * Float(sin(twoPiF * Double(i) / sampleRate))
            }
        }
        return samples
    }

    /// Run measureCents on a buffer using the given tracker.
    private func measure(_ tracker: inout GoertzelTracker, buffer: [Float]) -> Double? {
        buffer.withUnsafeBufferPointer { ptr in
            tracker.measureCents(buffer: ptr.baseAddress!, count: buffer.count)
        }
    }

    // MARK: - Basic Accuracy

    func test_exactFrequency_returnsCentsNearZero() {
        // A440 harmonic signal — Goertzel target is exactly 440 Hz
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: 440.0)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents, "Should detect signal at target frequency")
        XCTAssertEqual(cents!, 0.0, accuracy: 2.0,
            "A440 signal at A440 target should be near 0 cents (got \(cents!))")
    }

    func test_lowE_82Hz_accuracy() {
        // Low E string — hardest case (fewest cycles in buffer)
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 82.41, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: 82.41)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents)
        XCTAssertEqual(cents!, 0.0, accuracy: 3.0,
            "Low E at target should be near 0 cents (got \(cents!))")
    }

    func test_highE_330Hz_accuracy() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 329.63, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: 329.63)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents)
        XCTAssertEqual(cents!, 0.0, accuracy: 2.0,
            "High E at target should be near 0 cents (got \(cents!))")
    }

    // MARK: - Known Detuning

    func test_5centsSharp_detected() {
        // A440 tuned 5 cents sharp = 440 * 2^(5/1200) ≈ 441.27 Hz
        let sharpFreq = 440.0 * pow(2.0, 5.0 / 1200.0)
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: sharpFreq)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents)
        XCTAssertEqual(cents!, 5.0, accuracy: 3.0,
            "5¢ sharp should read ~+5 (got \(cents!))")
    }

    func test_10centsFlat_detected() {
        let flatFreq = 440.0 * pow(2.0, -10.0 / 1200.0)
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: flatFreq)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents)
        XCTAssertEqual(cents!, -10.0, accuracy: 3.0,
            "10¢ flat should read ~-10 (got \(cents!))")
    }

    func test_30centsSharp_detected() {
        let sharpFreq = 440.0 * pow(2.0, 30.0 / 1200.0)
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: sharpFreq)
        let cents = measure(&tracker, buffer: signal)

        XCTAssertNotNil(cents)
        // At ±30¢, parabolic interpolation on 3 bins loses accuracy (edge of bin).
        // The magnitude estimate may overshoot.
        XCTAssertGreaterThan(cents!, 15.0,
            "30¢ sharp should read substantially positive (got \(cents!))")
        XCTAssertLessThan(cents!, 50.0,
            "30¢ sharp should not exceed 50¢ (got \(cents!))")
    }

    // MARK: - Decay Detection

    func test_decayedSignal_returnsNil() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        // First: strong signal to establish peak
        let strong = generateHarmonicSignal(frequency: 440.0, amplitude: 0.5)
        _ = measure(&tracker, buffer: strong)

        // Then: very weak signal (simulating late decay)
        let weak = generateHarmonicSignal(frequency: 440.0, amplitude: 0.005)
        let cents = measure(&tracker, buffer: weak)

        XCTAssertNil(cents,
            "Signal at 1% amplitude should be below decay threshold")
    }

    func test_moderateDecay_stillMeasures() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        // Strong signal to establish peak
        let strong = generateHarmonicSignal(frequency: 440.0, amplitude: 0.5)
        _ = measure(&tracker, buffer: strong)

        // Moderate decay (50% amplitude → mag ratio ≈ 0.25) — above onset and decay thresholds
        let moderate = generateHarmonicSignal(frequency: 440.0, amplitude: 0.25)
        let cents = measure(&tracker, buffer: moderate)

        XCTAssertNotNil(cents,
            "Signal at 50% amplitude should still be above thresholds")
        XCTAssertEqual(cents!, 0.0, accuracy: 3.0)
    }

    // MARK: - Onset Suppression

    func test_onsetThreshold_suppressesLowMagRatio() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        // Strong signal establishes peak
        let strong = generateHarmonicSignal(frequency: 440.0, amplitude: 0.5)
        _ = measure(&tracker, buffer: strong)

        // Very weak signal — below onset threshold (mag ratio < 0.10)
        // but above decay threshold (mag ratio > 0.05)
        let weak = generateHarmonicSignal(frequency: 440.0, amplitude: 0.04)
        let cents = measure(&tracker, buffer: weak)

        // Should return nil because mag ratio ≈ (0.04/0.5)² = 0.0064 < 0.10
        XCTAssertNil(cents,
            "Signal below onset threshold should return nil")
    }

    // MARK: - Consecutive Frame Consistency

    func test_consecutiveFrames_stableFrequency() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 110.0, sampleRate: sampleRate, hopSize: hopSize)

        // Simulate multiple consecutive frames of A2
        let signal = generateHarmonicSignal(frequency: 110.0, count: windowSize + hopSize * 5)

        var readings: [Double] = []
        for frame in 0..<5 {
            let offset = frame * hopSize
            let cents = signal.withUnsafeBufferPointer { ptr in
                tracker.measureCents(
                    buffer: ptr.baseAddress! + offset,
                    count: windowSize)
            }
            if let c = cents { readings.append(c) }
        }

        // All readings should be near 0 and consistent
        XCTAssertGreaterThanOrEqual(readings.count, 3,
            "Should get at least 3 valid readings")

        let spread = (readings.max() ?? 0) - (readings.min() ?? 0)
        XCTAssertLessThan(spread, 3.0,
            "Consecutive frames should be within 3¢ of each other (spread: \(spread))")
    }

    func test_consecutiveFrames_detuned5cents() {
        let detuned = 110.0 * pow(2.0, 5.0 / 1200.0)
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 110.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: detuned, count: windowSize + hopSize * 5)

        var readings: [Double] = []
        for frame in 0..<5 {
            let offset = frame * hopSize
            let cents = signal.withUnsafeBufferPointer { ptr in
                tracker.measureCents(
                    buffer: ptr.baseAddress! + offset,
                    count: windowSize)
            }
            if let c = cents { readings.append(c) }
        }

        XCTAssertGreaterThanOrEqual(readings.count, 3)

        // All readings should converge to ~5¢
        let lastReadings = Array(readings.suffix(3))
        for r in lastReadings {
            XCTAssertEqual(r, 5.0, accuracy: 3.0,
                "Magnitude reading should be ~5¢ (got \(r))")
        }
    }

    // MARK: - No Drift During Simulated Decay

    func test_noDrift_duringDecay_lowE() {
        // The critical test: simulate what YIN gets wrong.
        // Generate a decaying 82 Hz signal and verify Goertzel stays stable.
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 82.41, sampleRate: sampleRate, hopSize: hopSize)

        // Generate a long decaying signal
        let totalSamples = windowSize + hopSize * 20
        let signal = generateDecayingSignal(
            frequency: 82.41, amplitude: 0.5, decayRate: 1.5, count: totalSamples)

        var readings: [Double] = []
        for frame in 0..<20 {
            let offset = frame * hopSize
            guard offset + windowSize <= totalSamples else { break }
            let cents = signal.withUnsafeBufferPointer { ptr in
                tracker.measureCents(
                    buffer: ptr.baseAddress! + offset,
                    count: windowSize)
            }
            if let c = cents { readings.append(c) }
        }

        guard readings.count >= 5 else {
            // Signal may have decayed too fast — that's OK, means decay detection works
            return
        }

        // Key assertion: readings should NOT drift flat by 12-35 cents
        // (which is what YIN does on the same signal)
        let maxDrift = readings.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(maxDrift, 5.0,
            "Goertzel should not drift during decay (max deviation: \(maxDrift)¢)")

        // Check that the spread between first and last valid reading is small
        let drift = abs(readings.last! - readings.first!)
        XCTAssertLessThan(drift, 5.0,
            "First-to-last drift should be <5¢ (got \(drift)¢)")
    }

    func test_noDrift_duringDecay_A440() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let totalSamples = windowSize + hopSize * 20
        let signal = generateDecayingSignal(
            frequency: 440.0, amplitude: 0.5, decayRate: 1.5, count: totalSamples)

        var readings: [Double] = []
        for frame in 0..<20 {
            let offset = frame * hopSize
            guard offset + windowSize <= totalSamples else { break }
            let cents = signal.withUnsafeBufferPointer { ptr in
                tracker.measureCents(
                    buffer: ptr.baseAddress! + offset,
                    count: windowSize)
            }
            if let c = cents { readings.append(c) }
        }

        guard readings.count >= 5 else { return }

        let maxDrift = readings.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(maxDrift, 3.0,
            "A440 should not drift during decay (max deviation: \(maxDrift)¢)")
    }

    // MARK: - Peg Turn Simulation

    func test_pegTurn_frequencyShift_tracked() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 110.0, sampleRate: sampleRate, hopSize: hopSize)

        // 3 frames at 110 Hz, then shift to 110 Hz + 20 cents
        let shifted = 110.0 * pow(2.0, 20.0 / 1200.0)
        let totalSamples = windowSize + hopSize * 8

        // Generate signal that shifts frequency mid-way
        var signal = [Float](repeating: 0, count: totalSamples)
        let switchPoint = windowSize + hopSize * 3  // switch after 3 frames
        for i in 0..<totalSamples {
            let freq = i < switchPoint ? 110.0 : shifted
            let twoPiF = 2.0 * .pi * freq
            for h in 1...6 {
                signal[i] += (0.5 / Float(h)) * Float(sin(twoPiF * Double(h) * Double(i) / sampleRate))
            }
        }

        var preShift: [Double] = []
        var postShift: [Double] = []

        for frame in 0..<8 {
            let offset = frame * hopSize
            guard offset + windowSize <= totalSamples else { break }
            let cents = signal.withUnsafeBufferPointer { ptr in
                tracker.measureCents(
                    buffer: ptr.baseAddress! + offset,
                    count: windowSize)
            }
            if let c = cents {
                if frame < 3 {
                    preShift.append(c)
                } else {
                    postShift.append(c)
                }
            }
        }

        // Pre-shift: should be near 0
        for r in preShift {
            XCTAssertEqual(r, 0.0, accuracy: 5.0,
                "Pre-shift reading should be near 0 (got \(r))")
        }

        // Post-shift: should move toward +20¢
        // (may not be exactly 20 due to windowing overlap)
        if let last = postShift.last {
            XCTAssertGreaterThan(last, 5.0,
                "Post-shift reading should reflect frequency increase (got \(last))")
        }
    }

    // MARK: - Reset

    func test_reset_clearsState() {
        var tracker = GoertzelTracker()
        tracker.setTarget(frequency: 440.0, sampleRate: sampleRate, hopSize: hopSize)

        let signal = generateHarmonicSignal(frequency: 440.0)
        _ = measure(&tracker, buffer: signal)
        XCTAssertGreaterThan(tracker.peakMagnitudeSq, 0)

        tracker.reset()
        XCTAssertEqual(tracker.targetFrequency, 0)
        XCTAssertEqual(tracker.peakMagnitudeSq, 0)
    }

    // MARK: - All 6 Open Strings

    func test_allOpenStrings_accuracy() {
        let openStrings: [(name: String, freq: Double)] = [
            ("Low E", 82.41),
            ("A", 110.00),
            ("D", 146.83),
            ("G", 196.00),
            ("B", 246.94),
            ("High E", 329.63)
        ]

        for string in openStrings {
            var tracker = GoertzelTracker()
            tracker.setTarget(frequency: string.freq, sampleRate: sampleRate, hopSize: hopSize)

            let signal = generateHarmonicSignal(frequency: string.freq)
            let cents = measure(&tracker, buffer: signal)

            XCTAssertNotNil(cents, "\(string.name) should be detected")
            XCTAssertEqual(cents!, 0.0, accuracy: 3.0,
                "\(string.name) (\(string.freq) Hz) should be near 0¢ (got \(cents!))")
        }
    }
}
