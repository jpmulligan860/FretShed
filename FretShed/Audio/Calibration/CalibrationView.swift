// CalibrationView.swift
// FretShed — Audio Layer
//
// 4-screen TabView(.page) calibration flow:
//   0 — Welcome   (explanation, detected input source, "Start" button)
//   1 — Silence   ("Stay quiet for 3 seconds", live level bar, progress ring)
//   2 — Strings   ("Play String N (note)", live detection, checkmarks)
//   3 — Results   (quality score, per-string checkmarks, "Save & Close")
//
// Presented as .fullScreenCover from ContentView or SettingsView.

import SwiftUI

// MARK: - CalibrationView

struct CalibrationView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    @State private var engine = CalibrationEngine()
    @State private var currentPage: Int = 0

    /// When true, skips the welcome screen (re-calibration from Settings).
    var isRecalibration: Bool = false

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                welcomeScreen.tag(0)
                silenceScreen.tag(1)
                stringScreen.tag(2)
                resultsScreen.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            .navigationTitle("Audio Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if engine.phase != .complete {
                        Button("Cancel") {
                            engine.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        .task {
            // Detect input source immediately so the welcome screen
            // shows the correct device name (e.g. "USB Audio Interface").
            engine.detectInputSource()

            if isRecalibration {
                engine = CalibrationEngine(isRecalibration: true)
                engine.detectInputSource()
                currentPage = 1
                await engine.startSilenceMeasurement()
            }
        }
        .onChange(of: engine.phase) { _, newPhase in
            switch newPhase {
            case .welcome:
                currentPage = 0
            case .measuringNoise:
                currentPage = 1
            case .testingString:
                currentPage = 2
            case .complete:
                currentPage = 3
            }
        }
        .onDisappear {
            engine.cancel()
        }
    }

    // MARK: - Screen 0: Welcome

    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 72))
                .foregroundStyle(DesignSystem.Colors.cherry)

            Text("Audio Calibration")
                .font(DesignSystem.Typography.screenTitle)

            Text("This process measures your environment's noise level and tests detection for each guitar string. It takes about 30 seconds.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Label("Detected Input:", systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold))
                Text(engine.detectedInputSource.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))

            Spacer()

            Button {
                Task { await engine.startSilenceMeasurement() }
            } label: {
                Text("Start Calibration")
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
    }

    // MARK: - Screen 1: Silence Measurement

    private var silenceScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: noiseProgress)
                    .stroke(DesignSystem.Colors.cherry, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: noiseProgress)
                Image(systemName: "waveform.path")
                    .font(.system(size: 32))
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .frame(width: 100, height: 100)

            Text("Measuring Silence")
                .font(DesignSystem.Typography.screenTitle)

            Text("Stay quiet for a few seconds.\nKeep your guitar still and don't play.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Live input level bar
            InputLevelBar(level: engine.detector.inputLevel)
                .frame(height: 28)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var noiseProgress: Double {
        if case .measuringNoise(let progress) = engine.phase {
            return progress
        }
        return 0
    }

    // MARK: - Screen 2: String Testing

    private var stringScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("String Test")
                .font(DesignSystem.Typography.screenTitle)

            Text("Play each open string when prompted.\nHold until the checkmark appears.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Current string prompt
            if let name = engine.currentStringName,
               let note = engine.expectedNote {
                VStack(spacing: 8) {
                    Text("Play:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(note.sharpName)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.cherry)
                }
                .padding()
            }

            // Live detection display
            if let detected = engine.detector.detectedNote {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.green)
                    Text("Hearing: \(detected.sharpName)")
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Input level bar
            InputLevelBar(level: engine.detector.inputLevel)
                .frame(height: 22)
                .padding(.horizontal, 32)

            // Per-string checkmarks
            stringChecklist
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var stringChecklist: some View {
        VStack(spacing: 8) {
            ForEach(CalibrationEngine.openStringNotes, id: \.string) { entry in
                HStack {
                    Image(systemName: engine.stringResults[entry.string] == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(engine.stringResults[entry.string] == true ? .green : .secondary)
                    Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                        .font(.subheadline)
                    Spacer()
                    if case .testingString(let num) = engine.phase, num == entry.string {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Screen 3: Results

    private var resultsScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            // Quality score ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(engine.signalQualityScore))
                    .stroke(qualityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(engine.signalQualityScore * 100))%")
                        .font(.system(size: 28, weight: .bold))
                    Text("Quality")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text("Calibration Complete")
                .font(DesignSystem.Typography.screenTitle)

            Text("Input: \(engine.detectedInputSource.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Per-string results
            VStack(spacing: 8) {
                ForEach(CalibrationEngine.openStringNotes, id: \.string) { entry in
                    HStack {
                        Image(systemName: engine.stringResults[entry.string] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(engine.stringResults[entry.string] == true ? .green : .red)
                        Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .padding(.horizontal, 32)

            Spacer()

            Button {
                saveAndClose()
            } label: {
                Text("Save & Close")
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
    }

    private var qualityColor: Color {
        if engine.signalQualityScore >= 0.8 { return .green }
        if engine.signalQualityScore >= 0.5 { return .orange }
        return .red
    }

    // MARK: - Save

    private func saveAndClose() {
        let profile = engine.buildProfile()
        try? container.calibrationRepository.save(profile)
        UserDefaults.standard.set(true, forKey: LocalUserPreferences.Key.hasCompletedCalibration)
        engine.cancel()
        dismiss()
    }
}

