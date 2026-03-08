//
//  TunerDisplayEngine.swift
//  FretShed
//
//  Interpolation buffer + gain-scheduled spring-damper for tuner needle.
//  Replaces EMA filter + SwiftUI .spring() with a single physics model.
//
//  Not @Observable — the TimelineView reads `currentCents` directly each
//  frame. Using @Observable would trigger "setting value during update"
//  crashes because update() mutates state during SwiftUI body evaluation.
//

import Foundation
import QuartzCore

final class TunerDisplayEngine {
    // MARK: - Output (read by the view via TimelineView)
    private(set) var currentCents: Double = 0

    // MARK: - Internal state
    private var velocity: Double = 0
    private var targetCents: Double = 0
    private var previousSample: (timestamp: CFTimeInterval, cents: Double)?
    private var currentSample: (timestamp: CFTimeInterval, cents: Double)?
    private var suppressionFramesRemaining: Int = 0
    private var lastNoteName: String?
    private var lastUpdateTime: CFTimeInterval = 0

    // Input smoothing: light EMA on incoming samples to reduce frame-to-frame
    // jitter from pitch detection variance (especially on low strings).
    private var smoothedInput: Double?
    private let inputAlpha: Double = 0.4  // 0.4 = responsive but smooths ±2¢ jitter

    // MARK: - Interpolation buffer

    func pushSample(cents: Double, note: String?) {
        let now = CACurrentMediaTime()

        // Transient suppression: if note changed, suppress for 3 frames
        // and freeze the needle at its current position to prevent jumping.
        if let note, note != lastNoteName, lastNoteName != nil {
            suppressionFramesRemaining = 3
            lastNoteName = note
            // Freeze: set target to current position so spring decelerates in place
            targetCents = currentCents
            velocity *= 0.2
            previousSample = nil
            currentSample = nil
            smoothedInput = nil
            return
        }
        lastNoteName = note

        // Apply light EMA to incoming cents to reduce pitch detection jitter
        let smoothed: Double
        if let prev = smoothedInput {
            smoothed = inputAlpha * cents + (1.0 - inputAlpha) * prev
        } else {
            smoothed = cents
        }
        smoothedInput = smoothed

        previousSample = currentSample
        currentSample = (timestamp: now, cents: smoothed)
    }

    func pushSilence() {
        // Hold at last reading — professional tuner behavior. The view fades
        // the needle opacity to indicate "note decayed, this was your last reading."
        // Returning to center during active tuning causes overshoot when tuning down.
        targetCents = currentCents
        velocity = 0
        lastNoteName = nil
        previousSample = nil
        currentSample = nil
        smoothedInput = nil
    }

    // MARK: - Per-frame update (called by TimelineView at display refresh rate)
    // Returns the current cents value for the needle position.

    @discardableResult
    func update(now: CFTimeInterval) -> Double {
        // Compute real dt from last update
        let dt: Double
        if lastUpdateTime > 0 {
            dt = min(now - lastUpdateTime, 1.0 / 30.0) // Cap at ~33ms to prevent huge jumps
        } else {
            dt = 1.0 / 60.0
        }
        lastUpdateTime = now

        // Handle suppression countdown
        if suppressionFramesRemaining > 0 {
            suppressionFramesRemaining -= 1
            // During suppression, spring-damper continues toward last target (natural deceleration)
        } else {
            // Interpolate between the two most recent samples
            if let prev = previousSample, let curr = currentSample, curr.timestamp > prev.timestamp {
                let t = min(max((now - prev.timestamp) / (curr.timestamp - prev.timestamp), 0), 1.2)
                targetCents = prev.cents + (curr.cents - prev.cents) * t
            } else if let curr = currentSample {
                targetCents = curr.cents
            }
        }

        // Second-order spring-damper with gain scheduling
        let error = targetCents - currentCents
        let absError = abs(error)

        let (stiffness, damping) = gainSchedule(absError)

        let acceleration = stiffness * error - damping * velocity
        velocity += acceleration * dt
        currentCents += velocity * dt

        // Clamp to prevent runaway
        currentCents = max(-55, min(55, currentCents))
        velocity = max(-500, min(500, velocity))

        return currentCents
    }

    private func gainSchedule(_ absError: Double) -> (stiffness: Double, damping: Double) {
        if absError > 15 {
            // Coarse: moderate tracking, critically damped — no overshoot
            return (300, 35)
        } else if absError > 5 {
            // Fine: moderate tracking, slightly overdamped
            return (200, 30)
        } else {
            // Precision: heavily overdamped — absorbs pitch detection variance
            return (80, 22)
        }
    }

    func reset() {
        currentCents = 0
        velocity = 0
        targetCents = 0
        previousSample = nil
        currentSample = nil
        suppressionFramesRemaining = 0
        lastNoteName = nil
        lastUpdateTime = 0
        smoothedInput = nil
    }
}
