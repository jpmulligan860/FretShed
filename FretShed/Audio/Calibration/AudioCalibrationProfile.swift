// AudioCalibrationProfile.swift
// FretShed — Audio Layer
//
// SwiftData model for persisted audio calibration profiles.
// Each profile captures the measured noise floor, AGC gain, and per-string
// detection results for a specific input source.

import Foundation
import SwiftData
import AVFoundation

// MARK: - AudioInputSource

/// Identifies the type of audio input device used during calibration.
public enum AudioInputSource: String, Codable, Sendable {
    case builtInMic     = "builtInMic"
    case usbInterface   = "usbInterface"
    case bluetoothAudio = "bluetoothAudio"
    case wiredHeadset   = "wiredHeadset"
    case unknown        = "unknown"

    /// Detects the current input source from AVAudioSession route info.
    /// Checks all inputs and prioritises USB over other external sources,
    /// with a name-based fallback for USB interfaces that register as
    /// headset devices (e.g. Boss Katana:GO).
    @MainActor
    public static func detectCurrent() -> AudioInputSource {
        let route = AVAudioSession.sharedInstance().currentRoute
        let inputs = route.inputs
        guard !inputs.isEmpty else { return .unknown }

        // First pass: look for an explicit USB audio port.
        for input in inputs {
            if input.portType == .usbAudio { return .usbInterface }
        }

        // Second pass: some USB interfaces (e.g. Boss Katana:GO) register
        // as .headsetMic. Check port name for USB-related keywords.
        let usbKeywords = ["usb", "interface", "katana", "scarlett",
                           "focusrite", "presonus", "steinberg",
                           "audient", "motu", "apollo", "id4", "id14"]
        for input in inputs where input.portType != .builtInMic {
            let name = input.portName.lowercased()
            if usbKeywords.contains(where: { name.contains($0) }) {
                return .usbInterface
            }
        }

        // Third pass: classify by port type.
        let input = inputs[0]
        switch input.portType {
        case .builtInMic:                          return .builtInMic
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return .bluetoothAudio
        case .headsetMic:                          return .wiredHeadset
        default:                                   return .unknown
        }
    }

    public var displayName: String {
        switch self {
        case .builtInMic:     return "Built-in Microphone"
        case .usbInterface:   return "USB Audio Interface"
        case .bluetoothAudio: return "Bluetooth Audio"
        case .wiredHeadset:   return "Wired Headset"
        case .unknown:        return "Unknown"
        }
    }
}

// MARK: - AudioCalibrationProfile

@Model
public final class AudioCalibrationProfile {

    @Attribute(.unique) public var id: UUID

    /// Raw value of `AudioInputSource` for SwiftData storage.
    public var inputSourceRaw: String

    /// Raw noise floor RMS measured during silence phase.
    public var measuredNoiseFloorRMS: Float

    /// AGC gain computed from string test phase.
    public var measuredAGCGain: Float

    /// When the calibration was performed.
    public var calibrationDate: Date

    /// Fraction of strings successfully detected (0.0–1.0).
    public var signalQualityScore: Float

    /// User-adjustable input gain trim in dB (±6 dB, default 0.0).
    public var userGainTrimDB: Float

    /// User-adjustable noise gate trim in dB (±6 dB, default 0.0).
    public var userGateTrimDB: Float

    /// JSON-encoded [Int: Bool] — string number → passed/failed.
    public var stringResultsData: Data

    // MARK: Computed

    public var inputSource: AudioInputSource {
        get { AudioInputSource(rawValue: inputSourceRaw) ?? .unknown }
        set { inputSourceRaw = newValue.rawValue }
    }

    /// Decoded per-string results. Key = string number (1–6), value = passed.
    public var stringResults: [Int: Bool] {
        get {
            (try? JSONDecoder().decode([Int: Bool].self, from: stringResultsData)) ?? [:]
        }
        set {
            stringResultsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: Initializer

    public init(
        inputSource: AudioInputSource,
        measuredNoiseFloorRMS: Float,
        measuredAGCGain: Float,
        signalQualityScore: Float,
        stringResults: [Int: Bool],
        userGainTrimDB: Float = 0.0,
        userGateTrimDB: Float = 0.0
    ) {
        self.id = UUID()
        self.inputSourceRaw = inputSource.rawValue
        self.measuredNoiseFloorRMS = measuredNoiseFloorRMS
        self.measuredAGCGain = measuredAGCGain
        self.calibrationDate = Date()
        self.signalQualityScore = signalQualityScore
        self.userGainTrimDB = userGainTrimDB
        self.userGateTrimDB = userGateTrimDB
        self.stringResultsData = (try? JSONEncoder().encode(stringResults)) ?? Data()
    }
}
