// CalibrationView.swift
// FretShed — Audio Layer
//
// 4-screen TabView(.page) calibration flow:
//   0 — Welcome   (explanation, detected input source, "Start" button)
//   1 — Silence   ("Stay quiet for 3 seconds", live level bar, progress ring)
//   2 — Strings   ("Play String N (note)", live detection, checkmarks)
//   3 — Results   (quality score, per-string checkmarks, profile naming)
//
// New profiles: "Save & Name Profile" → inline name field + guitar type picker → "Save Profile"
// Re-calibration (recalibratingProfile != nil): overwrites calibration data, keeps name/type.
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

    /// When set, overwrites this existing profile's calibration data (keeps name/type).
    var recalibratingProfile: AudioCalibrationProfile? = nil

    @State private var profileName: String = ""
    @State private var selectedGuitarType: GuitarType = .electric
    @State private var showNameEntry: Bool = false

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

            if isRecalibration || recalibratingProfile != nil {
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
            case .testingString, .testingFretted:
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

            Text("This process measures your environment's noise level and tests detection across your guitar. It takes about a minute.")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Label("Detected Input:", systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold))
                Text(engine.detectedInputSource.displayName)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.text2)
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
                    .stroke(DesignSystem.Colors.surface2, lineWidth: 6)
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
                .foregroundStyle(DesignSystem.Colors.text2)
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

            if engine.isFrettedPhase {
                Text("12th Fret Test")
                    .font(DesignSystem.Typography.screenTitle)

                Text("Now play the same strings at the 12th fret.\nThe 12th fret is where the double dots are.")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Open String Test")
                    .font(DesignSystem.Typography.screenTitle)

                Text("Play each open string when prompted.\nHold until the checkmark appears.")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Current string prompt
            if let name = engine.currentStringName,
               let note = engine.expectedNote {
                VStack(spacing: 8) {
                    Text(engine.isFrettedPhase ? "Play 12th Fret:" : "Play:")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text(name)
                        .font(DesignSystem.Typography.subDisplay)
                    Text(note.sharpName)
                        .font(DesignSystem.Typography.quizNote)
                        .foregroundStyle(DesignSystem.Colors.cherry)
                }
                .padding()
            }

            // Live detection display
            if let detected = engine.detector.detectedNote {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(DesignSystem.Colors.correct)
                    Text("Hearing: \(detected.sharpName)")
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }

            // Input level bar
            InputLevelBar(level: engine.detector.inputLevel)
                .frame(height: 22)
                .padding(.horizontal, 32)

            // Per-string checkmarks — combined open + fretted
            stringChecklist
                .padding(.horizontal, 32)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: engine.isFrettedPhase)
    }

    private var stringChecklist: some View {
        HStack(alignment: .top, spacing: 16) {
            // Open strings column
            VStack(spacing: 6) {
                DesignSystem.Typography.capsLabel("OPEN STRINGS")
                    .foregroundStyle(DesignSystem.Colors.text)
                ForEach(CalibrationEngine.openStringNotes, id: \.string) { entry in
                    HStack(spacing: 6) {
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

            // 12th fret column
            VStack(spacing: 6) {
                DesignSystem.Typography.capsLabel("12TH FRET")
                    .foregroundStyle(DesignSystem.Colors.text)
                ForEach(CalibrationEngine.frettedStringNotes, id: \.string) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: engine.frettedStringResults[entry.string] == true ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(engine.frettedStringResults[entry.string] == true ? .green : .secondary)
                        Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                            .font(.subheadline)
                        Spacer()
                        if case .testingFretted(let num) = engine.phase, num == entry.string {
                            ProgressView()
                                .controlSize(.small)
                        }
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
                    .stroke(DesignSystem.Colors.surface2, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(engine.signalQualityScore))
                    .stroke(qualityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(engine.signalQualityScore * 100))%")
                        .font(DesignSystem.Typography.subDisplay)
                    Text("Quality")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .frame(width: 120, height: 120)

            Text("Calibration Complete")
                .font(DesignSystem.Typography.screenTitle)

            Text("Input: \(engine.detectedInputSource.displayName)")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.text2)

            // Per-string results — open + fretted side by side
            HStack(alignment: .top, spacing: 16) {
                // Open strings column
                VStack(spacing: 6) {
                    DesignSystem.Typography.capsLabel("OPEN STRINGS")
                        .foregroundStyle(DesignSystem.Colors.text)
                    ForEach(CalibrationEngine.openStringNotes, id: \.string) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: engine.stringResults[entry.string] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(engine.stringResults[entry.string] == true ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong)
                            Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }

                // 12th fret column
                VStack(spacing: 6) {
                    DesignSystem.Typography.capsLabel("12TH FRET")
                        .foregroundStyle(DesignSystem.Colors.text)
                    ForEach(CalibrationEngine.frettedStringNotes, id: \.string) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: engine.frettedStringResults[entry.string] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(engine.frettedStringResults[entry.string] == true ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong)
                            Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            .padding(.horizontal, 32)

            Spacer()

            if recalibratingProfile != nil {
                // Re-calibrating an existing profile — skip naming, just save
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
            } else if showNameEntry {
                // Naming UI
                VStack(spacing: 16) {
                    TextField("Profile Name (e.g. Strat, Acoustic)", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)

                    Picker("Guitar Type", selection: $selectedGuitarType) {
                        ForEach(GuitarType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    Button {
                        saveAndClose()
                    } label: {
                        Text("Save Profile")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.cherry, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            } else {
                Button {
                    showNameEntry = true
                } label: {
                    Text("Save & Name Profile")
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
    }

    private var qualityColor: Color {
        if engine.signalQualityScore >= 0.8 { return DesignSystem.Colors.correct }
        if engine.signalQualityScore >= 0.5 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    // MARK: - Save

    private func saveAndClose() {
        if let existing = recalibratingProfile {
            // Re-calibration: overwrite calibration data on existing profile, keep name/type
            let newProfile = engine.buildProfile()
            existing.inputSourceRaw = newProfile.inputSourceRaw
            existing.measuredNoiseFloorRMS = newProfile.measuredNoiseFloorRMS
            existing.measuredAGCGain = newProfile.measuredAGCGain
            existing.calibrationDate = newProfile.calibrationDate
            existing.signalQualityScore = newProfile.signalQualityScore
            existing.stringResultsData = newProfile.stringResultsData
            existing.frettedStringResultsData = newProfile.frettedStringResultsData
            try? container.calibrationRepository.save(existing)
        } else {
            // New profile: set name, guitar type, mark as active
            let profile = engine.buildProfile()
            let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.name = trimmedName.isEmpty ? nil : trimmedName
            profile.guitarType = selectedGuitarType
            profile.isActive = true

            // Deactivate all other profiles, then save
            if let allProfiles = try? container.calibrationRepository.allProfiles() {
                for p in allProfiles { p.isActive = false }
            }
            try? container.calibrationRepository.save(profile)

            // Sync active ID to UserDefaults
            UserDefaults.standard.set(profile.id.uuidString, forKey: LocalUserPreferences.Key.activeCalibrationProfileID)
        }

        UserDefaults.standard.set(true, forKey: LocalUserPreferences.Key.hasCompletedCalibration)

        // Enable audio detection mode now that calibration is complete
        if let settings = try? container.settingsRepository.loadSettings() {
            settings.tapModeEnabled = false
            try? container.settingsRepository.saveSettings(settings)
        }

        engine.cancel()
        dismiss()
    }
}

