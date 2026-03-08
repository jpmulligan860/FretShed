//
//  DecayStabilizerTests.swift
//  FretShedTests
//
//  Tests for decay-phase pitch stabilization covering both amplitude-based
//  and time-based locking, plus spike-based peg turn detection.
//
//  Default parameters:
//  - decayDropThreshold: 0.10 (~5 dB amplitude lock)
//  - maxUnlockedFrames: 20 (~230ms time lock)
//  - spikeThreshold: 0.5 ¢/frame for peg turn detection
//  - spikeFrames: 2 consecutive spike frames to confirm
//

import XCTest
@testable import FretShed

final class DecayStabilizerTests: XCTestCase {

    // MARK: - Helpers

    /// Run a stabilizer through frames, returning display values.
    static func run(
        _ s: inout DecayStabilizer,
        frames: [(rmsLevel: Float, medianCents: Double)]
    ) -> [Double] {
        frames.map { s.process(rmsLevel: $0, medianCents: $1).cents }
    }

    /// Simulate USB interface: slow decay, high SNR.
    static func usbDecay(
        peakLevel: Float = 0.85,
        decayRate: Float = 0.001,
        trueCents: Double = 0.0,
        driftPerFrame: Double = -0.15,
        frameCount: Int = 300
    ) -> [(Float, Double)] {
        (0..<frameCount).map { i in
            (max(0.05, peakLevel - Float(i) * decayRate),
             trueCents + Double(i) * driftPerFrame)
        }
    }

    /// Simulate built-in mic: fast decay, lower SNR.
    static func micDecay(
        peakLevel: Float = 0.7,
        decayRate: Float = 0.005,
        trueCents: Double = 0.0,
        driftPerFrame: Double = -0.15,
        frameCount: Int = 200
    ) -> [(Float, Double)] {
        (0..<frameCount).map { i in
            (max(0.05, peakLevel - Float(i) * decayRate),
             trueCents + Double(i) * driftPerFrame)
        }
    }

    // MARK: - Time-based lock (critical for USB interfaces)

    func test_timeLock_triggersAt20Frames() {
        var s = DecayStabilizer()

        // High, constant signal — amplitude lock never triggers
        for i in 0..<25 {
            let (_, updated) = s.process(rmsLevel: 0.85, medianCents: 0.0)
            if i < 20 {
                XCTAssertTrue(updated, "Should update before time lock (frame \(i))")
                XCTAssertFalse(s.isLocked, "Should not be locked before frame 20")
            }
        }
        XCTAssertTrue(s.isLocked, "Should be time-locked after 20 frames")
    }

    func test_timeLock_preventsUSBDrift() {
        var s = DecayStabilizer()
        // USB: signal stays at 0.85 for entire duration, drift at 0.15/frame
        let frames = Self.usbDecay(decayRate: 0.0, driftPerFrame: -0.15, frameCount: 200)
        let display = Self.run(&s, frames: frames)

        // Without time lock, raw drift = 200 * 0.15 = 30¢
        // Time lock at frame 20, drift at that point = 20 * 0.15 = 3.0¢
        let maxDev = display.map { abs($0) }.max()!
        XCTAssertLessThan(maxDev, 5.0,
            "USB drift should be suppressed by time lock (got \(maxDev)¢)")
    }

    func test_timeLock_locksBeforeAmplitudeDrop_USB() {
        var s = DecayStabilizer()
        // USB: very slow decay (0.001/frame) — amplitude lock at frame 100+
        let frames = Self.usbDecay(driftPerFrame: -0.15, frameCount: 100)
        let display = Self.run(&s, frames: frames)

        // Time lock should fire at frame 20, well before amplitude threshold
        XCTAssertEqual(s.framesSinceTrackingStart, 100)
        let maxDev = display.map { abs($0) }.max()!
        XCTAssertLessThan(maxDev, 5.0,
            "Time lock should catch USB drift before amplitude lock (got \(maxDev)¢)")
    }

    // MARK: - Amplitude-based lock (for mic/fast decay)

    func test_amplitudeLock_triggersOnFastDecay() {
        var s = DecayStabilizer()
        // Mic: fast decay hits amplitude threshold before time lock
        for i in 0..<15 {
            let level: Float = 0.7 - Float(i) * 0.01
            _ = s.process(rmsLevel: level, medianCents: 0.0)
            if i >= 10 {
                // 0.7 - 10*0.01 = 0.60, threshold = 0.7 - 0.10 = 0.60
                // Lock should trigger around frame 11
            }
        }
        XCTAssertTrue(s.isLocked, "Amplitude lock should trigger on fast decay")
        XCTAssertLessThan(s.framesSinceTrackingStart, 20,
            "Should lock before time threshold on fast decay")
    }

    func test_micDecay_driftSuppressed() {
        var s = DecayStabilizer()
        let frames = Self.micDecay(driftPerFrame: -0.15, frameCount: 200)
        let display = Self.run(&s, frames: frames)

        let maxDev = display.map { abs($0) }.max()!
        XCTAssertLessThan(maxDev, 5.0,
            "Mic decay drift should be suppressed (got \(maxDev)¢)")
    }

    // MARK: - Drift suppression (both paths)

    func test_stablePitch_noDrift() {
        var s = DecayStabilizer()
        let frames: [(Float, Double)] = (0..<100).map { _ in (0.8, 2.0) }
        let display = Self.run(&s, frames: frames)

        XCTAssertEqual(display.last!, 2.0, accuracy: 0.1)
    }

    func test_heavyDrift_020_suppressed() {
        var s = DecayStabilizer()
        let frames = Self.usbDecay(driftPerFrame: -0.20, frameCount: 200)
        let display = Self.run(&s, frames: frames)

        let maxDev = display.map { abs($0) }.max()!
        XCTAssertLessThan(maxDev, 6.0,
            "Heavy drift should be suppressed (got \(maxDev)¢, raw = 40¢)")
    }

    // MARK: - Peg turn breakout

    func test_pegTurn_5cents_breaksThrough() {
        var s = DecayStabilizer()

        // Establish and lock
        for _ in 0..<25 { _ = s.process(rmsLevel: 0.85, medianCents: 0.0) }
        XCTAssertTrue(s.isLocked)

        // Peg turn: median ramps 0 → 2.5 → 5.0 (raw spikes)
        _ = s.process(rmsLevel: 0.85, medianCents: 2.5, rawCents: 4.0)  // raw delta = 4.0
        let r = s.process(rmsLevel: 0.85, medianCents: 5.0, rawCents: 5.5)  // raw delta = 1.5

        XCTAssertTrue(r.shouldUpdate, "5¢ peg turn should break through")
        XCTAssertEqual(r.cents, 5.0, accuracy: 0.1)
    }

    func test_pegTurn_2cents_breaksThrough() {
        var s = DecayStabilizer()

        for _ in 0..<25 { _ = s.process(rmsLevel: 0.85, medianCents: 0.0) }

        // 2-cent peg turn: raw jumps from ~0 to 2.0 (delta > 0.5 → spike)
        // With spikeFrames=1, single frame breaks through immediately.
        let r = s.process(rmsLevel: 0.85, medianCents: 1.0, rawCents: 2.0)

        XCTAssertTrue(r.shouldUpdate)
        XCTAssertEqual(r.cents, 1.0, accuracy: 0.1)  // display uses medianCents
    }

    func test_slowDrift_doesNotBreakThrough() {
        var s = DecayStabilizer()

        for _ in 0..<25 { _ = s.process(rmsLevel: 0.85, medianCents: 0.0) }

        // Slow drift at 0.3 ¢/frame (below 0.5 threshold)
        var brokeThrough = false
        for i in 1...30 {
            let (cents, updated) = s.process(
                rmsLevel: 0.85, medianCents: Double(i) * 0.3, rawCents: Double(i) * 0.3)
            if updated && cents > 1.0 { brokeThrough = true }
        }

        XCTAssertFalse(brokeThrough, "0.3 ¢/frame should NOT trigger spike")
    }

    func test_pegTurnDuringDecay_thenRelocks() {
        var s = DecayStabilizer()

        for _ in 0..<25 { _ = s.process(rmsLevel: 0.85, medianCents: 0.0) }

        // Peg turn breaks through
        _ = s.process(rmsLevel: 0.80, medianCents: 1.5, rawCents: 3.0)
        _ = s.process(rmsLevel: 0.80, medianCents: 3.0, rawCents: 3.2)

        // Drift after peg turn — should stay locked at 3.0
        var maxDrift: Double = 0
        for i in 0..<50 {
            let (d, _) = s.process(
                rmsLevel: 0.78, medianCents: 3.0 + Double(i) * -0.15,
                rawCents: 3.0 + Double(i) * -0.15)
            maxDrift = max(maxDrift, abs(d - 3.0))
        }

        XCTAssertLessThan(maxDrift, 4.0,
            "Should re-lock after peg turn (drift: \(maxDrift)¢)")
    }

    // MARK: - Reset

    func test_reset_clearsAllState() {
        var s = DecayStabilizer()
        for _ in 0..<25 { _ = s.process(rmsLevel: 0.8, medianCents: 0.0) }
        XCTAssertTrue(s.isLocked)

        s.reset()
        XCTAssertEqual(s.peakLevel, 0)
        XCTAssertNil(s.lockedCents)
        XCTAssertFalse(s.isLocked)
        XCTAssertEqual(s.framesSinceTrackingStart, 0)
    }

    // MARK: - Realistic scenarios

    func test_scenario_USB_lowE_3secondSustain() {
        // Low E through USB: signal barely drops, heavy drift
        var s = DecayStabilizer()
        var frames: [(rmsLevel: Float, medianCents: Double)] = []
        for i in 0..<258 {
            let level = max(Float(0.3), Float(0.85) - Float(i) * Float(0.001))
            let cents = -1.0 + Double(i) * -0.12
            frames.append((level, cents))
        }
        let display = Self.run(&s, frames: frames)

        // Time lock at frame 20, drift at that point = 20 * 0.12 = 2.4¢
        let maxDev = display.map { abs($0 - (-1.0)) }.max()!
        XCTAssertLessThan(maxDev, 5.0,
            "USB low E should be time-locked (max dev: \(maxDev)¢)")
    }

    func test_scenario_USB_dString_worstCase() {
        // D string through USB: heaviest drift
        var s = DecayStabilizer()
        var frames: [(rmsLevel: Float, medianCents: Double)] = []
        for i in 0..<200 {
            let level = max(Float(0.3), Float(0.80) - Float(i) * Float(0.001))
            let cents = -2.0 + Double(i) * -0.18
            frames.append((level, cents))
        }
        let display = Self.run(&s, frames: frames)

        let finalDisplay = display.last!
        let rawFinal = -2.0 + 199.0 * -0.18  // -37.8
        XCTAssertGreaterThan(finalDisplay, -8.0,
            "USB D string should be locked (display: \(finalDisplay)¢, raw: \(rawFinal)¢)")
    }

    func test_scenario_acoustic_mic_fastDecay() {
        // Acoustic through mic: fast decay, amplitude lock triggers first
        var s = DecayStabilizer()
        let frames = Self.micDecay(
            peakLevel: 0.65, decayRate: 0.008,
            trueCents: 0.5, driftPerFrame: -0.12, frameCount: 150)
        let display = Self.run(&s, frames: frames)

        let maxDev = display.map { abs($0 - 0.5) }.max()!
        XCTAssertLessThan(maxDev, 5.0,
            "Acoustic mic decay should be amplitude-locked (max dev: \(maxDev)¢)")
    }

    // MARK: - Parameter sweeps

    func test_parameterSweep_maxUnlockedFrames() {
        let frameValues = [10, 15, 20, 25, 30, 40]

        for maxFrames in frameValues {
            var s = DecayStabilizer()
            s.maxUnlockedFrames = maxFrames

            // USB-like: constant high level, drift from frame 0
            var maxDrift: Double = 0
            for i in 0..<200 {
                let (d, _) = s.process(rmsLevel: 0.85, medianCents: Double(i) * -0.15)
                maxDrift = max(maxDrift, abs(d))
            }

            let preLockDrift = Double(maxFrames) * 0.15
            print("maxUnlockedFrames=\(maxFrames): max drift=\(String(format: "%.1f", maxDrift))¢, expected pre-lock=\(String(format: "%.1f", preLockDrift))¢")

            // Drift should be roughly equal to pre-lock accumulation + 1 frame
            XCTAssertLessThan(maxDrift, preLockDrift + 1.0,
                "Frames=\(maxFrames): drift \(maxDrift)¢ exceeds expected \(preLockDrift + 1.0)¢")
        }
    }

    func test_parameterSweep_spikeThreshold() {
        let thresholds: [Double] = [0.3, 0.5, 0.7, 1.0]

        for threshold in thresholds {
            var s = DecayStabilizer()
            s.spikeThreshold = threshold

            for _ in 0..<25 { _ = s.process(rmsLevel: 0.85, medianCents: 0.0) }

            // YIN drift should never trigger spike
            var maxDrift: Double = 0
            for i in 0..<100 {
                let (d, _) = s.process(rmsLevel: 0.85, medianCents: Double(i) * -0.15)
                maxDrift = max(maxDrift, abs(d))
            }

            print("Spike \(threshold)¢/frame: max drift after lock = \(String(format: "%.1f", maxDrift))¢")
            XCTAssertLessThan(maxDrift, 4.0,
                "Spike \(threshold): drift should stay locked (got \(maxDrift)¢)")
        }
    }
}
