// SignalMeasurementTests.swift
// FretShed — Unit Tests
//
// Verifies the numeric behaviour of SignalMeasurement utilities.

import Accelerate
import XCTest
@testable import FretShed

final class SignalMeasurementTests: XCTestCase {

    // MARK: - Helpers

    /// Allocates a sine wave buffer at the given frequency/amplitude.
    /// Caller must `defer { buf.deallocate() }`.
    private func makeSineBuffer(hz: Float, amplitude: Float, count: Int) -> UnsafeMutablePointer<Float> {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        let sampleRate: Float = 44100
        for i in 0..<count {
            buf[i] = amplitude * sin(2 * Float.pi * hz * Float(i) / sampleRate)
        }
        return buf
    }

    // MARK: - rms()

    func test_rms_silenceBuffer_returnsZero() {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
        defer { buf.deallocate() }
        buf.initialize(repeating: 0, count: 1024)
        XCTAssertEqual(SignalMeasurement.rms(buffer: buf, count: 1024), 0.0)
    }

    func test_rms_knownAmplitudeSine_returnsAmplitudeOverSqrt2() {
        let count = 44100
        let amplitude: Float = 0.5
        let buf = makeSineBuffer(hz: 440, amplitude: amplitude, count: count)
        defer { buf.deallocate() }
        let expected = amplitude / sqrt(2)
        XCTAssertEqual(SignalMeasurement.rms(buffer: buf, count: count), expected, accuracy: 0.001)
    }

    func test_rms_fullScaleSine_returnsApprox0_707() {
        let count = 44100
        let buf = makeSineBuffer(hz: 440, amplitude: 1.0, count: count)
        defer { buf.deallocate() }
        XCTAssertEqual(SignalMeasurement.rms(buffer: buf, count: count), 1.0 / sqrt(2), accuracy: 0.001)
    }

    func test_rms_dcOffset_returnsAmplitude() {
        let count = 1024
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { buf.deallocate() }
        buf.initialize(repeating: 0.3, count: count)
        XCTAssertEqual(SignalMeasurement.rms(buffer: buf, count: count), 0.3, accuracy: 1e-6)
    }

    func test_rms_zeroCount_returnsZero() {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        defer { buf.deallocate() }
        buf[0] = 1.0
        XCTAssertEqual(SignalMeasurement.rms(buffer: buf, count: 0), 0.0)
    }

    // MARK: - normaliseToLevel()

    func test_normaliseToLevel_silence_returnsZero() {
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: 0.0), 0.0)
    }

    func test_normaliseToLevel_minus50dBFS_returnsZero() {
        let rms = pow(10.0 as Float, -50.0 / 20.0)
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: rms), 0.0, accuracy: 0.001)
    }

    func test_normaliseToLevel_zeroDB_returnsOne() {
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: 1.0), 1.0)
    }

    func test_normaliseToLevel_minus25dBFS_returnsApprox0_5() {
        let rms = pow(10.0 as Float, -25.0 / 20.0)
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: rms), 0.5, accuracy: 0.001)
    }

    func test_normaliseToLevel_belowFloor_clampedToZero() {
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: 1e-12), 0.0)
    }

    func test_normaliseToLevel_aboveCeiling_clampedToOne() {
        XCTAssertEqual(SignalMeasurement.normaliseToLevel(rms: 10.0), 1.0)
    }

    // MARK: - noiseFloorStep()

    func test_noiseFloorStep_rmsBelowFloor_floorDropsToRms() {
        XCTAssertEqual(SignalMeasurement.noiseFloorStep(current: 0.01, rms: 0.005), 0.005)
    }

    func test_noiseFloorStep_rmsAboveFloor_floorRisesSlowly() {
        let result = SignalMeasurement.noiseFloorStep(current: 0.01, rms: 0.05)
        XCTAssertEqual(result, 0.01002, accuracy: 1e-6)
    }

    func test_noiseFloorStep_rmsEqualFloor_floorUnchanged() {
        // rms is not < current, so the slow-rise branch executes
        // result = 0.01 + (0.01 - 0.01) * 0.0005 = 0.01
        XCTAssertEqual(SignalMeasurement.noiseFloorStep(current: 0.01, rms: 0.01), 0.01, accuracy: 1e-6)
    }

    func test_noiseFloorStep_slowRiseCoefficient_isCorrect() {
        var floor: Float = 0.0
        for _ in 0..<1000 {
            floor = SignalMeasurement.noiseFloorStep(current: floor, rms: 1.0)
        }
        // After 1000 iterations: 1 - (1 - 0.0005)^1000 ≈ 0.3935
        XCTAssertEqual(floor, 0.3935, accuracy: 0.001)
    }

    // MARK: - gateThreshold()

    func test_gateThreshold_lowFloor_returnsMinimumClamp() {
        XCTAssertEqual(SignalMeasurement.gateThreshold(noiseFloor: 0.0001), 0.002)
    }

    func test_gateThreshold_normalFloor_returnsFourTimesFloor() {
        XCTAssertEqual(SignalMeasurement.gateThreshold(noiseFloor: 0.01), 0.04, accuracy: 1e-6)
    }

    // MARK: - spectralFlatness()

    func test_spectralFlatness_flatSpectrum_returnsNearOne() {
        let count = 1024
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { buf.deallocate() }
        buf.initialize(repeating: 0.5, count: count)
        let result = SignalMeasurement.spectralFlatness(powerSpectrum: buf, count: count)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func test_spectralFlatness_singleSpike_returnsNearZero() {
        let count = 1024
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { buf.deallocate() }
        buf.initialize(repeating: 1e-10, count: count)
        buf[100] = 1.0
        let result = SignalMeasurement.spectralFlatness(powerSpectrum: buf, count: count)
        XCTAssertLessThan(result, 0.01)
    }

    func test_spectralFlatness_guitarLikeSpectrum_returnsLow() {
        let count = 2048
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { buf.deallocate() }
        buf.initialize(repeating: 1e-6, count: count)
        buf[50]  = 1.0
        buf[100] = 0.3
        buf[150] = 0.1
        buf[200] = 0.05
        buf[250] = 0.02
        let result = SignalMeasurement.spectralFlatness(powerSpectrum: buf, count: count)
        XCTAssertLessThan(result, 0.15, "Guitar-like spectrum should be clearly tonal")
    }

    func test_spectralFlatness_zeroSpectrum_returnsOne() {
        let count = 512
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { buf.deallocate() }
        buf.initialize(repeating: 0, count: count)
        let result = SignalMeasurement.spectralFlatness(powerSpectrum: buf, count: count)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    func test_spectralFlatness_emptyCount_returnsOne() {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        defer { buf.deallocate() }
        buf[0] = 1.0
        let result = SignalMeasurement.spectralFlatness(powerSpectrum: buf, count: 0)
        XCTAssertEqual(result, 1.0)
    }
}
