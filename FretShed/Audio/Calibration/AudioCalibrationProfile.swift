// AudioCalibrationProfile.swift
// FretShed — Audio Layer
//
// SwiftData model for persisted audio calibration profiles.
// Each profile captures the measured noise floor, AGC gain, and per-string
// detection results for a specific input source. Multiple profiles can be
// stored (one per guitar); the active profile (isActive) is used for quiz
// pitch detection pre-seeding.

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

// MARK: - GuitarType

/// Identifies the type of guitar used during calibration.
public enum GuitarType: String, CaseIterable, Codable, Sendable {
    case electric  = "electric"
    case acoustic  = "acoustic"
    case classical = "classical"

    public var displayName: String {
        switch self {
        case .electric:  return "Electric"
        case .acoustic:  return "Acoustic"
        case .classical: return "Classical"
        }
    }

    public var iconName: String {
        switch self {
        case .electric:  return "guitars.fill"
        case .acoustic:  return "guitars"
        case .classical: return "guitars"
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

    /// JSON-encoded [Int: Bool] — string number → passed/failed at 12th fret.
    public var frettedStringResultsData: Data

    /// User-assigned profile name (e.g. "Strat", "Acoustic").
    public var name: String?

    /// Raw value of `GuitarType` for SwiftData storage.
    public var guitarTypeRaw: String?

    /// Whether this is the currently active calibration profile.
    public var isActive: Bool = false

    // MARK: Computed

    public var inputSource: AudioInputSource {
        get { AudioInputSource(rawValue: inputSourceRaw) ?? .unknown }
        set { inputSourceRaw = newValue.rawValue }
    }

    public var guitarType: GuitarType? {
        get { guitarTypeRaw.flatMap { GuitarType(rawValue: $0) } }
        set { guitarTypeRaw = newValue?.rawValue }
    }

    /// Display name for the profile, falling back to "Guitar" if unnamed.
    public var displayName: String {
        if let name, !name.isEmpty { return name }
        return "Guitar"
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

    /// Decoded per-string 12th-fret results. Key = string number (1–6), value = passed.
    public var frettedStringResults: [Int: Bool] {
        get {
            (try? JSONDecoder().decode([Int: Bool].self, from: frettedStringResultsData)) ?? [:]
        }
        set {
            frettedStringResultsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: Initializer

    public init(
        inputSource: AudioInputSource,
        measuredNoiseFloorRMS: Float,
        measuredAGCGain: Float,
        signalQualityScore: Float,
        stringResults: [Int: Bool],
        frettedStringResults: [Int: Bool] = [:],
        userGainTrimDB: Float = 0.0,
        userGateTrimDB: Float = 0.0,
        name: String? = nil,
        guitarType: GuitarType? = nil,
        isActive: Bool = false
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
        self.frettedStringResultsData = (try? JSONEncoder().encode(frettedStringResults)) ?? Data()
        self.name = name
        self.guitarTypeRaw = guitarType?.rawValue
        self.isActive = isActive
    }
}
