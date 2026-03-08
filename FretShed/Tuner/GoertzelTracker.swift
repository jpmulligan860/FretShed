// GoertzelTracker.swift
// FretShed — Audio Layer
//
// Precision frequency measurement using the Goertzel algorithm.
// Used by the tuner after YIN identifies a note: Goertzel tracks the
// cents deviation from the target frequency without the flat-ward drift
// that plagues autocorrelation-based methods during signal decay.
//
// Architecture:
//   1. YIN identifies the note (e.g., "A2 at ~110 Hz") — unchanged
//   2. GoertzelTracker measures energy at the target frequency ± neighbors
//   3. Parabolic interpolation on 3 bins gives sub-cent frequency estimate
//   4. Energy threshold detects decay → stops updating (consumer holds)
//
// The Goertzel algorithm computes the DFT at a single frequency in O(N).
// Unlike YIN's autocorrelation (which searches across all lags and wanders
// at low SNR), Goertzel evaluates at a fixed frequency — there is no
// search space to drift through.

import Foundation
import Accelerate

/// Goertzel-based pitch tracker for precise cents measurement during sustain.
/// Pure value type — no AVAudioEngine dependencies, fully unit-testable.
struct GoertzelTracker {

    // MARK: - Configuration

    /// Minimum magnitude-squared ratio (vs peak) to consider the signal valid.
    /// 0.0025 = 0.05² ≈ -26 dB from peak. Below this, magnitude estimates
    /// are noise-dominated and we stop updating.
    var decayThreshold: Double = 0.0025

    /// Minimum magnitude ratio (vs peak) before publishing a reading.
    /// Suppresses transient outliers during the attack phase when peak
    /// magnitude hasn't stabilized yet.
    var onsetThreshold: Double = 0.10

    // MARK: - Diagnostics (read-only, for debug overlay)

    /// Which method was used for the last measurement.
    private(set) var lastMethod: String = "none"

    /// Current magnitude / peak magnitude (0.0–1.0). Drops during decay.
    var magnitudeRatio: Double {
        peakMagnitudeSq > 0 ? lastMagnitudeSq / peakMagnitudeSq : 0
    }
    private var lastMagnitudeSq: Double = 0

    // MARK: - State

    /// Peak magnitude-squared seen since the target was set. Used for
    /// relative decay detection (pluck-strength-independent).
    private(set) var peakMagnitudeSq: Double = 0

    /// Pre-computed Hann window (allocated once per target change).
    private var hannWindow: [Float] = []

    /// Scratch buffer for windowed samples.
    private var windowedBuffer: [Float] = []

    // MARK: - Target

    /// The equal-temperament frequency we're measuring deviation from.
    private(set) var targetFrequency: Double = 0

    /// Sample rate of the audio stream.
    private(set) var sampleRate: Double = 44100

    // MARK: - API

    /// Set the target frequency after YIN identifies a note.
    /// Call this when entering tracking mode.
    mutating func setTarget(frequency: Double, sampleRate: Double, hopSize: Int) {
        self.targetFrequency = frequency
        self.sampleRate = sampleRate
        self.peakMagnitudeSq = 0
    }

    /// Reset all state (on note change or tracking exit).
    mutating func reset() {
        targetFrequency = 0
        peakMagnitudeSq = 0
    }

    /// Measure cents deviation from the target frequency.
    ///
    /// Returns `nil` if:
    /// - The signal has decayed below the energy threshold (-26 dB from peak)
    /// - The signal is still in the onset phase (mag ratio < 0.10)
    ///
    /// The consumer should hold the last good reading when this returns nil.
    ///
    /// - Parameters:
    ///   - buffer: Raw analysis buffer (pre-AGC'd, post-HPF). Will be
    ///     windowed internally — the input buffer is not modified.
    ///   - count: Number of samples in the buffer (typically 4096).
    /// - Returns: Cents deviation from the target, or nil if decayed/onset.
    mutating func measureCents(
        buffer: UnsafePointer<Float>,
        count: Int
    ) -> Double? {
        guard targetFrequency > 0, targetFrequency.isFinite,
              sampleRate > 0, count > 0 else { return nil }

        // Ensure Hann window is the right size
        if hannWindow.count != count {
            hannWindow = [Float](repeating: 0, count: count)
            vDSP_hann_window(&hannWindow, vDSP_Length(count), Int32(vDSP_HANN_NORM))
            windowedBuffer = [Float](repeating: 0, count: count)
        }

        // Apply Hann window (Goertzel needs windowed data to reduce spectral leakage)
        hannWindow.withUnsafeBufferPointer { win in
            windowedBuffer.withUnsafeMutableBufferPointer { out in
                vDSP_vmul(buffer, 1, win.baseAddress!, 1, out.baseAddress!, 1, vDSP_Length(count))
            }
        }

        // --- 3-bin Goertzel with parabolic interpolation ---
        let binWidth = sampleRate / Double(count)  // ~10.77 Hz for 4096 @ 44100

        let magCtr = goertzelMagnitudeSq(
            targetFrequency: targetFrequency, count: count)
        let magLo = goertzelMagnitudeSq(
            targetFrequency: targetFrequency - binWidth, count: count)
        let magHi = goertzelMagnitudeSq(
            targetFrequency: targetFrequency + binWidth, count: count)

        // Track peak magnitude for decay detection
        if magCtr > peakMagnitudeSq {
            peakMagnitudeSq = magCtr
        }

        // Track last magnitude for diagnostic ratio
        lastMagnitudeSq = magCtr

        // Decay detection: signal dropped below threshold
        guard peakMagnitudeSq > 0, magCtr > peakMagnitudeSq * decayThreshold else {
            lastMethod = "decayed"
            return nil
        }

        // Onset suppression: don't publish until energy has stabilized
        let ratio = magCtr / peakMagnitudeSq
        guard ratio >= onsetThreshold else {
            lastMethod = "onset"
            return nil
        }

        // --- Parabolic interpolation on magnitude ---
        let m0 = sqrt(magLo)
        let m1 = sqrt(magCtr)
        let m2 = sqrt(magHi)

        let denom = m0 - 2.0 * m1 + m2
        let cents: Double
        if abs(denom) > 1e-10 {
            let offset = 0.5 * (m0 - m2) / denom  // fractional bin offset
            let estimatedFreq = targetFrequency + offset * binWidth
            if estimatedFreq > 0 {
                cents = 1200.0 * log2(estimatedFreq / targetFrequency)
            } else {
                cents = 0.0
            }
        } else {
            cents = 0.0
        }

        guard cents.isFinite else {
            lastMethod = "invalid"
            return nil
        }

        lastMethod = "magnitude"
        return cents
    }

    // MARK: - Goertzel Core

    /// Compute the DFT magnitude squared at a single frequency using Goertzel.
    /// Uses the windowed buffer (set up by measureCents).
    private func goertzelMagnitudeSq(
        targetFrequency freq: Double,
        count: Int
    ) -> Double {
        let k = freq * Double(count) / sampleRate
        let w = 2.0 * .pi * k / Double(count)
        let coeff = 2.0 * cos(w)

        var s1: Double = 0
        var s2: Double = 0

        for i in 0..<count {
            let s0 = Double(windowedBuffer[i]) + coeff * s1 - s2
            s2 = s1
            s1 = s0
        }

        let real = s1 - s2 * cos(w)
        let imaginary = s2 * sin(w)
        return real * real + imaginary * imaginary
    }
}
