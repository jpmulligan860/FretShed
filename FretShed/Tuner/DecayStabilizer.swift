//
//  DecayStabilizer.swift
//  FretShed
//
//  Prevents YIN flat-ward drift during note decay while allowing real
//  pitch changes (peg turns) to break through via spike detection.
//
//  Two lock triggers (whichever fires first):
//  1. Amplitude: signal drops decayDropThreshold below peak (~5 dB)
//  2. Time: maxUnlockedFrames reached (~250ms) — critical for USB interfaces
//     where the signal stays strong for seconds
//
//  Spike detection uses frame-to-frame rate of change on raw cents (pre-median)
//  for minimal latency (~23ms vs ~103ms through the median window).
//

import Foundation

struct DecayStabilizer {
    // MARK: - Configuration

    /// Normalised-level drop from peak to trigger amplitude-based lock (~5 dB).
    var decayDropThreshold: Float = 0.10

    /// Maximum frames of tracking before forcing a lock, regardless of amplitude.
    /// At ~86 Hz update rate, 20 frames ≈ 230ms — enough for attack to settle
    /// and median to fill. Critical for USB interfaces where signal stays strong.
    var maxUnlockedFrames: Int = 20

    /// Minimum frame-to-frame delta (cents) on raw signal to indicate a peg turn.
    /// YIN drift is ~0.15 ¢/frame; peg turns produce 0.5+ ¢/frame spikes.
    var spikeThreshold: Double = 0.5

    /// Consecutive spike frames needed to confirm a real peg turn.
    /// With raw cents (pre-median), a step change produces only 1 frame of
    /// large delta, so this should be 1. The 3x margin between spike threshold
    /// (0.5) and drift rate (0.15) prevents false triggers.
    var spikeFrames: Int = 1

    // MARK: - State
    private(set) var peakLevel: Float = 0
    private(set) var lockedCents: Double? = nil
    private(set) var framesSinceTrackingStart: Int = 0
    private var spikeCount: Int = 0
    private var previousRaw: Double? = nil

    /// Whether the reading is currently locked (decay or time-based).
    var isLocked: Bool {
        lockedCents != nil
    }

    // MARK: - Interface

    /// Process a new frame during tracking mode.
    /// - Parameters:
    ///   - rmsLevel: Normalised RMS level (0–1)
    ///   - medianCents: Median-filtered cents for display value
    ///   - rawCents: Pre-median cents for spike detection (optional, defaults to medianCents)
    /// - Returns: The cents to display, and whether the display should update.
    mutating func process(rmsLevel: Float, medianCents: Double, rawCents: Double? = nil) -> (cents: Double, shouldUpdate: Bool) {
        peakLevel = max(peakLevel, rmsLevel)
        framesSinceTrackingStart += 1

        // Spike detection on raw cents for fast peg-turn response
        let spike = rawCents ?? medianCents
        let delta = previousRaw.map { abs(spike - $0) } ?? 0
        previousRaw = spike

        // Lock triggers: amplitude drop OR time elapsed (whichever first)
        let amplitudeLock = rmsLevel < peakLevel - decayDropThreshold
        let timeLock = framesSinceTrackingStart > maxUnlockedFrames
        let shouldLock = amplitudeLock || timeLock

        if shouldLock {
            if let locked = lockedCents {
                // Already locked — check for peg turn spike
                if delta >= spikeThreshold {
                    spikeCount += 1
                    if spikeCount >= spikeFrames {
                        // Peg turn confirmed — update lock to current median
                        lockedCents = medianCents
                        spikeCount = 0
                        return (medianCents, true)
                    }
                    return (locked, false)
                } else {
                    spikeCount = 0
                    return (locked, false)
                }
            } else {
                // First lock — capture current median as reference
                lockedCents = medianCents
                spikeCount = 0
                return (medianCents, true)
            }
        } else {
            // Not yet locked — pass through median for display
            return (medianCents, true)
        }
    }

    /// Reset all state (call when entering tracking mode or changing notes).
    mutating func reset() {
        peakLevel = 0
        lockedCents = nil
        framesSinceTrackingStart = 0
        spikeCount = 0
        previousRaw = nil
    }
}
