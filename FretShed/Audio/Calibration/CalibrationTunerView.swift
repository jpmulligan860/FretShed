// CalibrationTunerView.swift
// FretShed — Audio Layer
//
// Tuner view with calibration-specific messaging.
// Presented as fullScreenCover from ContentView when user taps
// "Use Audio Detection" on the Do This First card.
//
// Flow:
//   1. User sees tuner UI + instructional messaging
//   2. User tunes guitar
//   3. User taps "Calibrate" → CalibrationView runs (nested fullScreenCover)
//   4. On success → timed success overlay (~2 seconds) → auto-dismiss
//   5. ContentView detects dismissal + calibration complete → opens Session Setup

import SwiftUI

struct CalibrationTunerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var detector = PitchDetector()
    @State private var showCalibration = false
    @State private var showSuccess = false

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat
    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Instructional header
                    VStack(spacing: 6) {
                        Text("Tune Your Guitar")
                            .font(DesignSystem.Typography.screenTitle)
                        Text("Tune each string, then tap Calibrate to set up audio detection")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.text2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)

                    noteHeader
                        .padding(.top, 24)

                    TunerNeedleDisplay(
                        cents: detector.centsDeviation,
                        isActive: detector.detectedNote != nil
                    )
                    .padding(.top, 24)
                    .animation(.easeInOut(duration: 0.15), value: detector.centsDeviation)

                    centsReadout
                        .padding(.top, 16)

                    TunerCentsScale()
                        .padding(.top, 8)
                        .padding(.horizontal, 40)

                    InputLevelBar(level: detector.inputLevel)
                        .padding(.top, 6)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button {
                        Task {
                            await detector.stop()
                            showCalibration = true
                        }
                    } label: {
                        Label("Calibrate", systemImage: "waveform.badge.mic")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.cherry, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }

                if showSuccess {
                    successOverlay
                        .transition(.opacity)
                }
            }
            .navigationTitle("Audio Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") {
                            Task { await detector.stop() }
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await applySettings()
            try? await detector.start()
        }
        .onDisappear {
            Task { await detector.stop() }
        }
        .fullScreenCover(isPresented: $showCalibration, onDismiss: {
            if hasCompletedCalibration {
                showSuccess = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    dismiss()
                }
            } else {
                // Calibration cancelled — restart tuner
                Task { try? await detector.start() }
            }
        }) {
            CalibrationView()
        }
    }

    // MARK: - Apply Settings

    private func applySettings() async {
        let loaded = try? container.settingsRepository.loadSettings()
        if let s = loaded {
            detector.referenceA = Double(s.referenceAHz)
            detector.confidenceThreshold = s.tunerSensitivity
            detector.forceBuiltInMic = s.forceBuiltInMic
        }
    }

    // MARK: - Note Header

    private var noteHeader: some View {
        VStack(spacing: 6) {
            if let note = detector.detectedNote {
                Text(note.displayName(format: noteFormat))
                    .font(DesignSystem.Typography.heroNote)
                    .foregroundStyle(tuningColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: note)

                if let freq = detector.detectedFrequency {
                    Text(String(format: "%.1f Hz", freq))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .contentTransition(.numericText())
                }
            } else {
                Text("–")
                    .font(DesignSystem.Typography.heroNote)
                    .foregroundStyle(DesignSystem.Colors.muted.opacity(0.5))
                Text(detector.isRunning ? "Play a note…" : "Starting…")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.muted)
            }
        }
        .frame(height: 100)
    }

    // MARK: - Cents Readout

    private var centsReadout: some View {
        let c = detector.centsDeviation
        let sign = c >= 0 ? "+" : ""
        return Text("\(sign)\(Int(c.rounded())) ¢")
            .font(DesignSystem.Typography.dataDisplay)
            .foregroundStyle(tuningColor)
            .contentTransition(.numericText())
            .opacity(detector.detectedNote != nil ? 1 : 0)
    }

    // MARK: - Tuning Colour

    private var tuningColor: Color {
        guard detector.detectedNote != nil else { return DesignSystem.Colors.muted }
        let absCents = abs(detector.centsDeviation)
        if absCents <= 5  { return DesignSystem.Colors.correct }
        if absCents <= 15 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            DesignSystem.Colors.background.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignSystem.Colors.correct)
                Text("Calibration Complete!")
                    .font(DesignSystem.Typography.screenTitle)
                Text("Setting up your practice session…")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }
}

// MARK: - Needle Display (self-contained tuner gauge)

private struct TunerNeedleDisplay: View {

    let cents: Double
    let isActive: Bool

    private var angle: Double {
        isActive ? (cents / 50.0) * 90.0 : -90
    }

    var body: some View {
        ZStack {
            TunerDialArc()
                .stroke(DesignSystem.Colors.surface2, lineWidth: 4)
                .frame(width: 240, height: 120)

            TunerDialArc()
                .trim(from: 0.44, to: 0.56)
                .stroke(DesignSystem.Colors.correct.opacity(0.35), lineWidth: 6)
                .frame(width: 240, height: 120)

            TunerDialTicks()
                .frame(width: 240, height: 120)

            TunerNeedle(angle: angle)
                .frame(width: 240, height: 120)
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: angle)

            Circle()
                .fill(DesignSystem.Colors.text)
                .frame(width: 10, height: 10)
                .offset(y: 60)
        }
        .frame(height: 130)
    }
}

private struct TunerDialArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let centre = CGPoint(x: rect.midX, y: rect.maxY)
        p.addArc(center: centre, radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

private struct TunerDialTicks: View {
    var body: some View {
        Canvas { ctx, size in
            let centre = CGPoint(x: size.width / 2, y: size.height)
            let r = size.width / 2
            for i in stride(from: -50, through: 50, by: 10) {
                let angleDeg = 180.0 + Double(i + 50) / 100.0 * 180.0
                let rad = angleDeg * .pi / 180
                let isMajor = i % 50 == 0 || i == 0
                let len: CGFloat = isMajor ? 14 : 8
                let inner = CGPoint(x: centre.x + (r - len) * cos(rad),
                                    y: centre.y + (r - len) * sin(rad))
                let outer = CGPoint(x: centre.x + r * cos(rad),
                                    y: centre.y + r * sin(rad))
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                ctx.stroke(path, with: .color(DesignSystem.Colors.text2),
                           lineWidth: isMajor ? 2 : 1)
            }
        }
    }
}

private struct TunerNeedle: View {
    let angle: Double

    var body: some View {
        Canvas { ctx, size in
            let centre = CGPoint(x: size.width / 2, y: size.height)
            let length = size.width / 2 - 8
            let totalDeg = 270.0 + angle
            let rad = totalDeg * .pi / 180
            let tip = CGPoint(x: centre.x + length * cos(rad),
                              y: centre.y + length * sin(rad))
            var path = Path()
            path.move(to: centre)
            path.addLine(to: tip)
            ctx.stroke(path, with: .color(DesignSystem.Colors.text), lineWidth: 2)
        }
    }
}

private struct TunerCentsScale: View {
    var body: some View {
        HStack {
            Text("-50¢").font(.caption).foregroundStyle(DesignSystem.Colors.text2)
            Spacer()
            Text("0").font(.caption.weight(.bold)).foregroundStyle(DesignSystem.Colors.correct)
            Spacer()
            Text("+50¢").font(.caption).foregroundStyle(DesignSystem.Colors.text2)
        }
    }
}
