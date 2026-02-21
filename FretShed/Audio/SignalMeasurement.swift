// SignalMeasurement.swift
// FretShed — Audio Layer
//
// Pure signal measurement utilities extracted from PitchDetector.
// All functions are actor-context-free and safe on the realtime thread.

import Accelerate

enum SignalMeasurement {

    /// RMS of `count` Float32 samples via vDSP_svesq. Returns 0 if count == 0.
    static func rms(buffer: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        var sum: Float = 0
        vDSP_svesq(buffer, 1, &sum, vDSP_Length(count))
        return sqrt(sum / Float(count))
    }

    /// Maps RMS → 0.0–1.0 display level: −50 dBFS → 0.0, 0 dBFS → 1.0.
    static func normaliseToLevel(rms: Float) -> Float {
        let db = 20 * log10(max(rms, 1e-10))
        return max(0, min(1, (db + 50) / 50))
    }

    /// Adaptive noise floor step: drops instantly if rms < current, rises
    /// slowly at coefficient 0.0005 otherwise.
    static func noiseFloorStep(current: Float, rms: Float) -> Float {
        if rms < current { return rms }
        return current + (rms - current) * 0.0005
    }

    /// Noise gate open threshold: max(noiseFloor × 4.0, 0.002).
    static func gateThreshold(noiseFloor: Float) -> Float {
        return max(noiseFloor * 4.0, 0.002)
    }
}
