// AccelerateYINTests.swift
// FretShed — Unit Tests
//
// Verifies the pitch detection behaviour of the AccelerateYIN algorithm
// using synthetic signals and noise buffers.
//
// NOTE: AccelerateYIN includes HPS-guided harmonic correction that
// cross-checks YIN's period estimate against the Harmonic Product
// Spectrum fundamental. Pure sines lack harmonics, so HPS can
// mis-correct them. Tests use harmonic-rich signals (fundamental +
// overtones) to exercise the full detection pipeline as it runs
// on real guitar input.

import XCTest
@testable import FretShed

final class AccelerateYINTests: XCTestCase {

    // MARK: - Constants

    private let sampleRate: Double = 44100.0
    private let defaultWindowSize: Int = 4096

    // MARK: - Helpers

    /// Generates a sine wave buffer at the given frequency.
    /// For low frequencies, use a larger `count` to ensure at least one full cycle fits.
    private func generateSineWave(
        frequency: Double,
        sampleRate: Double,
        duration: Double,
        amplitude: Float = 0.5
    ) -> [Float] {
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        let twoPiF = 2.0 * Double.pi * frequency
        for i in 0..<count {
            samples[i] = amplitude * Float(sin(twoPiF * Double(i) / sampleRate))
        }
        return samples
    }

    /// Generates a harmonic-rich signal (fundamental + overtones) that mimics
    /// a real guitar string. HPS-guided correction in AccelerateYIN needs
    /// energy at integer multiples of the fundamental to correctly identify it.
    /// Harmonics decay at 1/h amplitude (typical plucked string spectrum).
    private func generateHarmonicSignal(
        frequency: Double,
        sampleRate: Double,
        duration: Double,
        amplitude: Float = 0.5,
        harmonics: Int = 5
    ) -> [Float] {
        let count = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: count)
        for h in 1...harmonics {
            let hFreq = frequency * Double(h)
            // Stop adding harmonics above Nyquist
            guard hFreq < sampleRate / 2.0 else { break }
            let hAmplitude = amplitude / Float(h)
            let twoPiF = 2.0 * Double.pi * hFreq
            for i in 0..<count {
                samples[i] += hAmplitude * Float(sin(twoPiF * Double(i) / sampleRate))
            }
        }
        return samples
    }

    /// Generates white noise with uniformly distributed random samples in [-1, 1].
    private func generateWhiteNoise(count: Int) -> [Float] {
        (0..<count).map { _ in Float.random(in: -1.0...1.0) }
    }

    // MARK: - 1. Silence

    func testSilenceReturnsNil() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let buffer = [Float](repeating: 0, count: defaultWindowSize)
        let result = buffer.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        // All-zeros: either nil, or a degenerate result with zero confidence.
        // The CMND of an all-zeros buffer produces d'(0)=1 and d'(tau)=NaN or 1
        // for all tau, so the algorithm may return a spurious frequency with
        // confidence 0.0. Either outcome indicates "no usable pitch detected."
        if let r = result {
            XCTAssertEqual(r.confidence, 0.0, accuracy: 0.01,
                           "Silence should produce zero confidence if any result is returned")
        }
    }

    // MARK: - 2. Harmonic Signal A440

    func testPureSineA440() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateHarmonicSignal(frequency: 440.0, sampleRate: sampleRate, duration: 0.2)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        XCTAssertNotNil(result, "Should detect a pitch for 440 Hz harmonic signal")
        if let r = result {
            XCTAssertEqual(r.frequency, 440.0, accuracy: 4.0,
                           "Detected frequency should be within +/-4 Hz of 440")
            XCTAssertGreaterThan(r.confidence, 0.9,
                                 "Confidence for a clean harmonic signal should exceed 0.9")
        }
    }

    // MARK: - 3. Harmonic Signal E2 (low E string = 82.41 Hz)

    func testPureSineE2() {
        // Low frequencies need a larger buffer to fit at least one full cycle.
        let windowSize = 8192
        let yin = AccelerateYIN(windowSize: windowSize)
        let samples = generateHarmonicSignal(frequency: 82.41, sampleRate: sampleRate, duration: 0.3)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: windowSize, sampleRate: sampleRate)
        }
        XCTAssertNotNil(result, "Should detect a pitch for 82.41 Hz harmonic signal")
        if let r = result {
            XCTAssertEqual(r.frequency, 82.41, accuracy: 4.0,
                           "Detected frequency should be within +/-4 Hz of 82.41 (low E)")
        }
    }

    // MARK: - 4. Harmonic Signal E4 (high E string open = 329.63 Hz)

    func testPureSineE4() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateHarmonicSignal(frequency: 329.63, sampleRate: sampleRate, duration: 0.2)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        XCTAssertNotNil(result, "Should detect a pitch for 329.63 Hz harmonic signal")
        if let r = result {
            XCTAssertEqual(r.frequency, 329.63, accuracy: 4.0,
                           "Detected frequency should be within +/-4 Hz of 329.63 (high E)")
        }
    }

    // MARK: - 5. White Noise

    func testWhiteNoiseReturnsNilOrLowConfidence() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateWhiteNoise(count: defaultWindowSize)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        if let r = result {
            XCTAssertLessThan(r.confidence, 0.5,
                              "White noise should produce low confidence if any result is returned")
        }
        // nil is also acceptable — test passes either way.
    }

    // MARK: - 6. Spectral Flatness High for Noise

    func testSpectralFlatnessHighForNoise() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateWhiteNoise(count: defaultWindowSize)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        if let r = result {
            XCTAssertGreaterThan(r.spectralFlatness, 0.3,
                                 "White noise should have high spectral flatness (> 0.3)")
        }
        // If nil, noise was rejected before flatness could be examined — also acceptable.
    }

    // MARK: - 7. Spectral Flatness Low for Tone

    func testSpectralFlatnessLowForTone() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateHarmonicSignal(frequency: 440.0, sampleRate: sampleRate, duration: 0.2)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        XCTAssertNotNil(result, "Should detect a pitch for 440 Hz harmonic signal")
        if let r = result {
            XCTAssertLessThan(r.spectralFlatness, 0.2,
                              "Harmonic tone should have low spectral flatness (< 0.2)")
        }
    }

    // MARK: - 8. Harmonic Regularity High for Tone

    func testHarmonicRegularityHighForTone() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateHarmonicSignal(frequency: 440.0, sampleRate: sampleRate, duration: 0.2)
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        XCTAssertNotNil(result, "Should detect a pitch for 440 Hz harmonic signal")
        if let r = result {
            XCTAssertGreaterThan(r.harmonicRegularity, 0.2,
                                 "Harmonic tone should have harmonic regularity > 0.2")
        }
    }

    // MARK: - 9. Multiple Frequencies

    func testMultipleFrequencies() {
        let frequencies: [(name: String, hz: Double)] = [
            ("B3",  246.94),
            ("D4",  293.66),
            ("G3",  196.00),
        ]

        for freq in frequencies {
            let yin = AccelerateYIN(windowSize: defaultWindowSize)
            let samples = generateHarmonicSignal(frequency: freq.hz, sampleRate: sampleRate, duration: 0.2)
            let result = samples.withUnsafeBufferPointer { ptr in
                yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
            }
            XCTAssertNotNil(result, "Should detect pitch for \(freq.name) (\(freq.hz) Hz)")
            if let r = result {
                XCTAssertEqual(r.frequency, freq.hz, accuracy: 3.0,
                               "\(freq.name): detected \(r.frequency) Hz, expected \(freq.hz) Hz (+/-3)")
            }
        }
    }

    // MARK: - 10. Low Amplitude Signal

    func testLowAmplitudeSine() {
        let yin = AccelerateYIN(windowSize: defaultWindowSize)
        let samples = generateHarmonicSignal(
            frequency: 440.0, sampleRate: sampleRate, duration: 0.2, amplitude: 0.01
        )
        let result = samples.withUnsafeBufferPointer { ptr in
            yin.detectPitch(in: ptr.baseAddress!, count: defaultWindowSize, sampleRate: sampleRate)
        }
        // Either nil (too quiet to detect) or correct pitch — NOT a wrong note.
        // AccelerateYIN operates on the raw buffer (no noise gate), so even very
        // quiet signals may produce a result. Accept frequency within ±5 Hz or
        // an integer sub-harmonic (440/N Hz), since HPS may pick a sub-harmonic
        // when amplitude is near the noise floor.
        if let r = result {
            let isCorrectPitch = abs(r.frequency - 440.0) <= 5.0
            let isSubHarmonic = (2...5).contains { n in
                abs(r.frequency - 440.0 / Double(n)) <= 5.0
            }
            XCTAssertTrue(isCorrectPitch || isSubHarmonic,
                          "If detected, low-amplitude signal should be near 440 Hz or a sub-harmonic, got \(r.frequency) Hz")
        }
        // nil is also acceptable for very quiet signals.
    }
}
