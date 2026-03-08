#if DEBUG
// TunerDiagnosticView.swift
// FretShed — Debug-only tuner diagnostic tool
//
// Guided 6-string diagnostic that captures per-frame Goertzel and YIN data,
// then formats a clipboard-ready report for analysis.

import SwiftUI

// MARK: - Data Model

struct DiagnosticFrame {
    let timestamp: TimeInterval
    let yinFrequency: Double
    let yinConfidence: Double
    let goertzelCents: Double?
    let goertzelMethod: String
    let goertzelMagRatio: Double
    let publishedCents: Double
}

struct DiagnosticStringResult {
    let stringName: String
    let targetFrequency: Double
    let frames: [DiagnosticFrame]

    var frameCount: Int { frames.count }
    var goertzelFrames: [DiagnosticFrame] { frames.filter { $0.goertzelCents != nil } }

    var centsMean: Double? {
        let valid = goertzelFrames.compactMap(\.goertzelCents)
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }

    var centsRange: (min: Double, max: Double)? {
        let valid = goertzelFrames.compactMap(\.goertzelCents)
        guard let lo = valid.min(), let hi = valid.max() else { return nil }
        return (lo, hi)
    }

    var methodBreakdown: (magnitude: Int, onset: Int, decayed: Int) {
        var m = 0, o = 0, d = 0
        for frame in goertzelFrames {
            switch frame.goertzelMethod {
            case "magnitude": m += 1
            case "onset": o += 1
            case "decayed": d += 1
            default: break
            }
        }
        return (m, o, d)
    }
}

// MARK: - Diagnostic Engine

@MainActor @Observable
final class TunerDiagnosticEngine {
    enum State: Equatable {
        case idle
        case waitingForSilence(stringIndex: Int) // gap between strings
        case waitingForPluck(stringIndex: Int)
        case recording(stringIndex: Int)
        case done
    }

    private(set) var state: State = .idle
    private(set) var results: [DiagnosticStringResult] = []
    private(set) var currentFrames: [DiagnosticFrame] = []

    // Config
    let strings: [(name: String, note: String, targetHz: Double)] = [
        ("String 6", "Low E", 82.41),
        ("String 5", "A", 110.00),
        ("String 4", "D", 146.83),
        ("String 3", "G", 196.00),
        ("String 2", "B", 246.94),
        ("String 1", "High E", 329.63),
    ]

    var currentStringIndex: Int {
        switch state {
        case .waitingForSilence(let i), .waitingForPluck(let i), .recording(let i): return i
        default: return 0
        }
    }

    var currentStringName: String {
        guard currentStringIndex < strings.count else { return "" }
        return "\(strings[currentStringIndex].note) (\(strings[currentStringIndex].name))"
    }

    private var recordingStart: Date?
    private var silenceFrameCount = 0
    private let maxRecordSeconds: TimeInterval = 5.0
    private let silenceThreshold = 15 // frames of nil Goertzel → note decayed

    // MARK: - Control

    func start() {
        results.removeAll()
        currentFrames.removeAll()
        state = .waitingForPluck(stringIndex: 0)
    }

    func cancel() {
        state = .idle
        results.removeAll()
        currentFrames.removeAll()
    }

    // MARK: - Feed (called from onChange)

    func feed(detector: PitchDetector) {
        switch state {
        case .waitingForSilence(let idx):
            // Wait for the previous note to fully clear before accepting a new pluck.
            // Requires detector to report no note (nil) to confirm silence.
            if detector.detectedNote == nil {
                state = .waitingForPluck(stringIndex: idx)
            }

        case .waitingForPluck(let idx):
            // Detect that the user plucked — note appears
            if detector.detectedNote != nil, detector.diagGoertzelCents != nil {
                currentFrames.removeAll()
                silenceFrameCount = 0
                recordingStart = Date()
                state = .recording(stringIndex: idx)
                captureFrame(detector: detector)
            }

        case .recording(let idx):
            captureFrame(detector: detector)

            // Check for end conditions
            if detector.diagGoertzelCents == nil {
                silenceFrameCount += 1
            } else {
                silenceFrameCount = 0
            }

            let elapsed = Date().timeIntervalSince(recordingStart ?? Date())

            if silenceFrameCount >= silenceThreshold || elapsed >= maxRecordSeconds {
                // Finish this string
                let config = strings[idx]
                let result = DiagnosticStringResult(
                    stringName: "\(config.name): \(config.note)",
                    targetFrequency: config.targetHz,
                    frames: currentFrames
                )
                results.append(result)
                currentFrames.removeAll()

                // Advance to next string or finish
                let next = idx + 1
                if next < strings.count {
                    state = .waitingForSilence(stringIndex: next)
                } else {
                    state = .done
                }
            }

        case .idle, .done:
            break
        }
    }

    private func captureFrame(detector: PitchDetector) {
        let frame = DiagnosticFrame(
            timestamp: Date().timeIntervalSinceReferenceDate,
            yinFrequency: detector.diagYINFrequency,
            yinConfidence: detector.diagYINConfidence,
            goertzelCents: detector.diagGoertzelCents,
            goertzelMethod: detector.diagGoertzelMethod,
            goertzelMagRatio: detector.diagGoertzelMagRatio,
            publishedCents: detector.centsDeviation
        )
        currentFrames.append(frame)
    }

    // MARK: - Report

    func generateReport(sampleRate: Double, referenceA: Double, inputSource: String) -> String {
        var lines: [String] = []
        lines.append("FRETSHED TUNER DIAGNOSTIC")
        lines.append("Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Sample Rate: \(sampleRate) Hz")
        lines.append("Reference A: \(referenceA) Hz")
        lines.append("Input Source: \(inputSource)")
        lines.append("")

        for result in results {
            lines.append("=== \(result.stringName) (target: \(result.targetFrequency) Hz) ===")
            lines.append("Frames captured: \(result.frameCount)")

            let gf = result.goertzelFrames
            if let first = gf.first, let last = gf.last {
                lines.append(String(format: "YIN freq (first/last): %.2f / %.2f Hz",
                                    first.yinFrequency, last.yinFrequency))
                lines.append(String(format: "YIN conf (first/last): %.3f / %.3f",
                                    first.yinConfidence, last.yinConfidence))
                lines.append(String(format: "Goertzel cents (first/last): %.1f / %.1f",
                                    first.goertzelCents ?? 0, last.goertzelCents ?? 0))
            }

            let mb = result.methodBreakdown
            lines.append("Goertzel methods: magnitude=\(mb.magnitude) onset=\(mb.onset) decayed=\(mb.decayed)")

            if let last = gf.last {
                lines.append(String(format: "Mag ratio at end: %.4f", last.goertzelMagRatio))
            }

            lines.append(String(format: "Final displayed cents: %.1f", result.frames.last?.publishedCents ?? 0))

            if let range = result.centsRange {
                lines.append(String(format: "Cents range: %.1f to %.1f (spread: %.1f)",
                                    range.min, range.max, range.max - range.min))
            }
            if let mean = result.centsMean {
                lines.append(String(format: "Cents mean: %.2f", mean))
            }

            // Per-frame data (every 10th frame)
            lines.append("")
            lines.append("Frame\tYIN_Hz\tYIN_Conf\tGoertzel_¢\tMethod\tMagRatio\tDisplay_¢")
            for (i, frame) in result.frames.enumerated() where i % 10 == 0 {
                let gc = frame.goertzelCents.map { String(format: "%.1f", $0) } ?? "nil"
                lines.append(String(format: "%d\t%.2f\t%.3f\t%@\t%@\t%.4f\t%.1f",
                                    i, frame.yinFrequency, frame.yinConfidence,
                                    gc, frame.goertzelMethod, frame.goertzelMagRatio,
                                    frame.publishedCents))
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - View

struct TunerDiagnosticView: View {
    let detector: PitchDetector
    @State private var engine = TunerDiagnosticEngine()
    @State private var reportCopied = false

    var body: some View {
        VStack(spacing: 12) {
            switch engine.state {
            case .idle:
                Button("Run 6-String Diagnostic") {
                    engine.start()
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2), in: Capsule())
                .foregroundStyle(.blue)

            case .waitingForSilence:
                VStack(spacing: 6) {
                    Text("DIAGNOSTIC \(engine.currentStringIndex + 1)/6")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)

                    Text("Mute strings...")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("Wait for silence before next pluck")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

                Button("Cancel", role: .destructive) { engine.cancel() }
                    .font(.system(size: 12, design: .monospaced))

            case .waitingForPluck:
                VStack(spacing: 6) {
                    Text("DIAGNOSTIC \(engine.currentStringIndex + 1)/6")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)

                    Text("Pluck \(engine.currentStringName)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("Let it ring until it dims")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

                Button("Cancel", role: .destructive) { engine.cancel() }
                    .font(.system(size: 12, design: .monospaced))

            case .recording:
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("Recording \(engine.currentStringName)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Text("\(engine.currentFrames.count) frames")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

            case .done:
                VStack(spacing: 8) {
                    Text("DIAGNOSTIC COMPLETE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    Text("\(engine.results.count) strings captured")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)

                    // Quick summary
                    ForEach(Array(engine.results.enumerated()), id: \.offset) { _, result in
                        HStack {
                            Text(result.stringName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.gray)
                            Spacer()
                            if let mean = result.centsMean {
                                Text(String(format: "%+.1f¢", mean))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(abs(mean) < 3 ? .green : .orange)
                            }
                        }
                    }
                    .padding(.horizontal, 8)

                    HStack(spacing: 12) {
                        Button {
                            let report = engine.generateReport(
                                sampleRate: detector.diagSampleRate,
                                referenceA: detector.referenceA,
                                inputSource: detector.calibratedInputSource?.rawValue ?? "unknown"
                            )
                            UIPasteboard.general.string = report
                            reportCopied = true
                        } label: {
                            Label(reportCopied ? "Copied!" : "Copy Report",
                                  systemImage: reportCopied ? "checkmark" : "doc.on.clipboard")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.2), in: Capsule())
                                .foregroundStyle(.blue)
                        }

                        Button("Run Again") {
                            reportCopied = false
                            engine.start()
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.orange)
                    }

                    Button("Close") { engine.cancel() }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: detector.centsDeviation) { _, _ in
            engine.feed(detector: detector)
        }
        .onChange(of: detector.detectedNote) { _, _ in
            engine.feed(detector: detector)
        }
    }
}

// MARK: - Diagnostic Runner (launched from Settings > Developer)

struct DiagnosticRunnerView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var detector = PitchDetector()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Minimal tuner readout so the user can see what's being detected
                    if let note = detector.detectedNote {
                        Text(note.displayName(format: .sharps))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(String(format: "%+.1f¢", detector.centsDeviation))
                            .font(.system(size: 24, design: .monospaced))
                            .foregroundStyle(abs(detector.centsDeviation) < 5 ? .green : .orange)
                    } else {
                        Text("Waiting for signal…")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.gray)
                    }

                    TunerDiagnosticView(detector: detector)
                }
                .padding()
            }
            .navigationTitle("6-String Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task { await detector.stop() }
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Pre-seed calibration like TunerView does
            if let profile = try? container.calibrationRepository.activeProfile() {
                let gateTrimMultiplier = pow(10.0, profile.userGateTrimDB / 20.0)
                detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier
                detector.calibratedInputSource = profile.inputSource
            }
            detector.sustainMode = true
            try? await detector.start()
        }
    }
}
#endif
