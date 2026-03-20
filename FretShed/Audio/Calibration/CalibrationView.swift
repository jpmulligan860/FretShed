// CalibrationView.swift
// FretShed — Audio Layer
//
// Single-page stepped calibration flow:
//   Step 1 — Tune Your Guitar (embedded tuner, "Done Tuning" button)
//   Step 2 — Measure Background Noise (4s countdown → 6s measurement)
//   Step 3 — Open String Test (play each open string)
//   Step 4 — 12th Fret Test (play each string at 12th fret)
//   Step 5 — Save Profile (quality score, naming, save)
//
// Each step is a card. Completed steps show a green checkmark.
// The active step's card is expanded to show its content.
//
// Presented as .fullScreenCover from ContentView or SettingsView.

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "CalibrationView")

// MARK: - CalibrationStep

private enum CalibrationStep: Int, CaseIterable {
    case tuning = 1
    case measuringNoise = 2
    case openStrings = 3
    case frettedStrings = 4
    case saveProfile = 5

    var title: String {
        switch self {
        case .tuning:        return "Tune Your Guitar"
        case .measuringNoise: return "Measure Background Noise"
        case .openStrings:   return "Open String Test"
        case .frettedStrings: return "12th Fret Test"
        case .saveProfile:   return "Save Profile"
        }
    }

    var subtitle: String {
        switch self {
        case .tuning:        return "Make sure your guitar is in tune before we begin."
        case .measuringNoise: return "We'll listen to your room's background noise."
        case .openStrings:   return "Play each open string when prompted."
        case .frettedStrings: return "Play each note at the 12th fret when prompted."
        case .saveProfile:   return "Name your profile and save."
        }
    }
}

// MARK: - CalibrationView

struct CalibrationView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var engine = CalibrationEngine()

    /// When true, skips tuning step (re-calibration from Settings).
    var isRecalibration: Bool = false

    /// When true, always creates a new profile (never overwrites existing).
    var forceNewProfile: Bool = false

    /// When set, overwrites this existing profile's calibration data (keeps name/type).
    var recalibratingProfile: AudioCalibrationProfile? = nil

    @State private var profileName: String = ""
    @State private var selectedGuitarType: GuitarType = .electric
    @State private var showNameEntry: Bool = false
    @State private var existingActiveProfile: AudioCalibrationProfile? = nil

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat
    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    @State private var displayEngine = TunerDisplayEngine()
    @State private var tuningState: TuningState = .noSignal

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 6) {
                            Text("Audio Calibration")
                                .font(DesignSystem.Typography.screenTitle)
                                .foregroundStyle(DesignSystem.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Input: \(engine.detectedInputSource.displayName)")
                                .font(DesignSystem.Typography.bodyLabel)
                                .foregroundStyle(DesignSystem.Colors.text2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Step cards
                        ForEach(visibleSteps, id: \.rawValue) { step in
                            stepCard(for: step)
                                .id(step)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .onChange(of: currentStep) { _, newStep in
                    if let step = newStep {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(step, anchor: .top)
                        }
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                if engine.phase != .complete {
                    Button("Cancel") {
                        engine.cancel()
                        dismiss()
                    }
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
            }
        }
        .task {
            // Auto-detect existing active profile for overwrite (when not explicitly passed)
            if recalibratingProfile == nil && !forceNewProfile {
                do {
                    existingActiveProfile = try container.calibrationRepository.activeProfile()
                } catch {
                    logger.warning("Failed to load active profile: \(error.localizedDescription)")
                }
            }
            let skipTuning = isRecalibration || recalibratingProfile != nil || existingActiveProfile != nil
            if skipTuning {
                engine = CalibrationEngine(isRecalibration: true)
                engine.detectInputSource()
                engine.finishTuning()
            } else {
                engine.detectInputSource()
                await engine.startTuning()
            }
        }
        .onDisappear {
            engine.cancel()
        }
        .onChange(of: engine.detector.detectedNote) { oldNote, newNote in
            if newNote == nil && oldNote != nil {
                displayEngine.pushSilence()
                tuningState = .noSignal
            }
        }
        .onChange(of: engine.detector.centsDeviation) { _, newCents in
            guard engine.detector.detectedNote != nil else { return }
            let noteName = engine.detector.detectedNote?.displayName(format: noteFormat)
            displayEngine.pushSample(cents: newCents, note: noteName)
            let newState = displayEngine.tuningState
            if newState != tuningState {
                tuningState = newState
            }
        }
    }

    // MARK: - Current Step

    private var currentStep: CalibrationStep? {
        switch engine.phase {
        case .welcome, .tuning:
            return .tuning
        case .countdown, .measuringNoise:
            return .measuringNoise
        case .testingString:
            return .openStrings
        case .testingFretted:
            return .frettedStrings
        case .complete:
            return .saveProfile
        }
    }

    private var visibleSteps: [CalibrationStep] {
        if isRecalibration || recalibratingProfile != nil || existingActiveProfile != nil {
            // Skip tuning for re-calibration
            return CalibrationStep.allCases.filter { $0 != .tuning }
        }
        return CalibrationStep.allCases
    }

    private func stepState(for step: CalibrationStep) -> StepState {
        guard let current = currentStep else { return .upcoming }
        if step.rawValue < current.rawValue { return .complete }
        if step == current { return .active }
        return .upcoming
    }

    private enum StepState {
        case upcoming, active, complete
    }

    // MARK: - Step Card

    @ViewBuilder
    private func stepCard(for step: CalibrationStep) -> some View {
        let state = stepState(for: step)
        VStack(spacing: 0) {
            // Card header
            HStack(spacing: 12) {
                stepIndicator(for: step, state: state)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundStyle(DesignSystem.Colors.text)
                    if state != .active {
                        Text(step.subtitle)
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                }
                Spacer()
            }
            .padding()

            // Expanded content for active step
            if state == .active {
                Divider()
                    .padding(.horizontal)

                stepContent(for: step)
                    .padding()
            }
        }
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .animation(.easeInOut(duration: 0.3), value: state == .active)
    }

    private func stepIndicator(for step: CalibrationStep, state: StepState) -> some View {
        ZStack {
            switch state {
            case .complete:
                Circle()
                    .fill(DesignSystem.Colors.correct)
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(.white)
            case .active:
                Circle()
                    .fill(DesignSystem.Colors.cherry)
                    .frame(width: 32, height: 32)
                Text("\(step.rawValue)")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(.white)
            case .upcoming:
                Circle()
                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 2)
                    .frame(width: 32, height: 32)
                Text("\(step.rawValue)")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.muted)
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private func stepContent(for step: CalibrationStep) -> some View {
        switch step {
        case .tuning:
            tuningContent
        case .measuringNoise:
            noiseContent
        case .openStrings:
            openStringContent
        case .frettedStrings:
            frettedStringContent
        case .saveProfile:
            saveProfileContent
        }
    }

    // MARK: - Step 1: Tuning

    private var tuningContent: some View {
        VStack(spacing: 16) {
            // Note header
            tunerNoteHeader

            // Needle display (matches main TunerView)
            AnimatedNeedleView(displayEngine: displayEngine,
                               isActive: engine.detector.detectedNote != nil,
                               tuningState: tuningState)

            // Cents readout
            tunerCentsReadout

            // Cents scale
            CentsScale()
                .padding(.horizontal, 4)

            // Input level
            InputLevelBar(level: engine.detector.inputLevel)

            // A4 reference
            HStack(spacing: 6) {
                Image(systemName: "tuningfork")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                Text("A4 = 440 Hz")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
            }

            // Done tuning button
            Button {
                engine.finishTuning()
            } label: {
                Text("Done Tuning")
                    .font(DesignSystem.Typography.sectionHeader)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .backgroundStyle(DesignSystem.Gradients.primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var tunerNoteHeader: some View {
        VStack(spacing: 6) {
            if let note = engine.detector.detectedNote {
                Text(note.displayName(format: noteFormat))
                    .font(DesignSystem.Typography.noteDisplay)
                    .foregroundStyle(tunerNeedleColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: note)

                if let freq = engine.detector.detectedFrequency {
                    Text(String(format: "%.1f Hz", freq))
                        .font(DesignSystem.Typography.centsDisplay)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .contentTransition(.numericText())
                }
            } else {
                Text("\u{2013}")
                    .font(DesignSystem.Typography.noteDisplay)
                    .foregroundStyle(DesignSystem.Colors.muted)
                Text(engine.detector.isRunning ? "Play a note\u{2026}" : "Starting\u{2026}")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
        .frame(height: 110)
    }

    private var tunerCentsReadout: some View {
        TimelineView(.animation) { _ in
            let c = displayEngine.update(now: CACurrentMediaTime())
            let sign = c >= 0 ? "+" : ""
            Text("\(sign)\(String(format: "%.1f", c)) \u{00A2}")
                .font(DesignSystem.Typography.subDisplay)
                .foregroundStyle(tunerNeedleColor)
                .contentTransition(.numericText())
                .opacity(engine.detector.detectedNote != nil ? 1 : 0)
        }
    }

    private var tunerNeedleColor: Color {
        switch tuningState {
        case .noSignal: return DesignSystem.Colors.muted
        case .outOfRange: return DesignSystem.Colors.wrong
        case .approaching: return DesignSystem.Colors.amber
        case .inTune, .settled: return DesignSystem.Colors.correct
        }
    }

    // MARK: - Step 2: Noise Measurement

    private var noiseContent: some View {
        VStack(spacing: 16) {
            if case .countdown(let remaining) = engine.phase {
                Text("Get ready\u{2026}")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)

                Text("\(remaining)")
                    .font(DesignSystem.Typography.bpmDisplay)
                    .foregroundStyle(DesignSystem.Colors.cherry)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: remaining)

                Text("Stay quiet — don't touch your strings.")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .multilineTextAlignment(.center)
            } else {
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

                Text("Measuring\u{2026}")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)

                InputLevelBar(level: engine.detector.inputLevel)
                    .frame(height: 28)
            }
        }
    }

    private var noiseProgress: Double {
        if case .measuringNoise(let progress) = engine.phase {
            return progress
        }
        return 0
    }

    // MARK: - Step 3: Open Strings

    private var openStringContent: some View {
        VStack(spacing: 16) {
            stringPromptAndDetection
            stringChecklist(
                entries: CalibrationEngine.openStringNotes,
                results: engine.stringResults,
                activeString: { if case .testingString(let n) = engine.phase { return n }; return nil }
            )
        }
    }

    // MARK: - Step 4: Fretted Strings

    private var frettedStringContent: some View {
        VStack(spacing: 16) {
            stringPromptAndDetection
            stringChecklist(
                entries: CalibrationEngine.frettedStringNotes,
                results: engine.frettedStringResults,
                activeString: { if case .testingFretted(let n) = engine.phase { return n }; return nil }
            )
        }
    }

    private func stringChecklist(
        entries: [(string: Int, note: MusicalNote)],
        results: [Int: Bool],
        activeString: @escaping () -> Int?
    ) -> some View {
        VStack(spacing: 6) {
            ForEach(entries, id: \.string) { entry in
                let passed = results[entry.string] == true
                HStack(spacing: 8) {
                    Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(passed ? DesignSystem.Colors.correct : DesignSystem.Colors.muted)
                    Text(CalibrationEngine.stringNames[entry.string] ?? "String \(entry.string)")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                    Spacer()
                    if activeString() == entry.string {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Shared String Prompt

    private var stringPromptAndDetection: some View {
        VStack(spacing: 12) {
            // Current string prompt
            if let name = engine.currentStringName,
               let note = engine.expectedNote {
                VStack(spacing: 4) {
                    Text(engine.isFrettedPhase ? "Play 12th Fret:" : "Play:")
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text(name)
                        .font(DesignSystem.Typography.screenTitle)
                        .foregroundStyle(DesignSystem.Colors.text)
                    Text(note.sharpName)
                        .font(DesignSystem.Typography.screenTitle)
                        .foregroundStyle(DesignSystem.Colors.cherry)
                }
            }

            // Live detection
            if let detected = engine.detector.detectedNote {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(DesignSystem.Colors.correct)
                    Text("Hearing: \(detected.sharpName)")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text("Listening\u{2026}")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }

            // Input level
            InputLevelBar(level: engine.detector.inputLevel)
                .frame(height: 22)
        }
    }

    // MARK: - Step 5: Save Profile

    private var saveProfileContent: some View {
        VStack(spacing: 16) {
            // Quality score
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.surface2, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(engine.signalQualityScore))
                    .stroke(qualityColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(engine.signalQualityScore * 100))%")
                    .font(DesignSystem.Typography.subDisplay)
                    .foregroundStyle(DesignSystem.Colors.text)
            }
            .frame(width: 100, height: 100)

            // String results summary
            HStack(alignment: .top, spacing: 32) {
                resultsSummaryColumn("OPEN", entries: CalibrationEngine.openStringNotes, results: engine.stringResults)
                resultsSummaryColumn("12TH FRET", entries: CalibrationEngine.frettedStringNotes, results: engine.frettedStringResults)
            }
            .frame(maxWidth: .infinity)

            // Profile naming / save
            if recalibratingProfile != nil || existingActiveProfile != nil {
                Button {
                    saveAndClose()
                } label: {
                    Text("Save & Close")
                        .font(DesignSystem.Typography.sectionHeader)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .backgroundStyle(DesignSystem.Gradients.primary)
                }
                .buttonStyle(.plain)
            } else if showNameEntry {
                VStack(spacing: 12) {
                    TextField("Profile Name (e.g. Strat, Acoustic)", text: $profileName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Guitar Type", selection: $selectedGuitarType) {
                        ForEach(GuitarType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        saveAndClose()
                    } label: {
                        Text("Save Profile")
                            .font(DesignSystem.Typography.sectionHeader)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white)
                            .background(in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .backgroundStyle(DesignSystem.Gradients.primary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showNameEntry = true
                } label: {
                    Text("Save & Name Profile")
                        .font(DesignSystem.Typography.sectionHeader)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .backgroundStyle(DesignSystem.Gradients.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var qualityColor: Color {
        if engine.signalQualityScore >= 0.8 { return DesignSystem.Colors.correct }
        if engine.signalQualityScore >= 0.5 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    private func resultsSummaryColumn(
        _ label: String,
        entries: [(string: Int, note: MusicalNote)],
        results: [Int: Bool]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DesignSystem.Typography.capsLabel(label)
            ForEach(entries, id: \.string) { entry in
                let passed = results[entry.string] == true
                HStack(spacing: 4) {
                    Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(passed ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong)
                    Text(CalibrationEngine.stringNames[entry.string] ?? "")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                }
            }
        }
    }

    // MARK: - Save

    private func overwriteProfile(_ existing: AudioCalibrationProfile) {
        let newProfile = engine.buildProfile()
        existing.inputSourceRaw = newProfile.inputSourceRaw
        existing.measuredNoiseFloorRMS = newProfile.measuredNoiseFloorRMS
        existing.measuredAGCGain = newProfile.measuredAGCGain
        existing.calibrationDate = newProfile.calibrationDate
        existing.signalQualityScore = newProfile.signalQualityScore
        existing.stringResultsData = newProfile.stringResultsData
        existing.frettedStringResultsData = newProfile.frettedStringResultsData
        do {
            try container.calibrationRepository.save(existing)
        } catch {
            logger.error("Failed to save recalibrated profile: \(error.localizedDescription)")
        }
    }

    private func saveAndClose() {
        if let existing = recalibratingProfile {
            overwriteProfile(existing)
        } else if let existing = existingActiveProfile {
            overwriteProfile(existing)
        } else {
            let profile = engine.buildProfile()
            let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.name = trimmedName.isEmpty ? nil : trimmedName
            profile.guitarType = selectedGuitarType
            profile.isActive = true

            do {
                let allProfiles = try container.calibrationRepository.allProfiles()
                for p in allProfiles { p.isActive = false }
            } catch {
                logger.warning("Failed to load profiles for deactivation: \(error.localizedDescription)")
            }
            do {
                try container.calibrationRepository.save(profile)
            } catch {
                logger.error("Failed to save new calibration profile: \(error.localizedDescription)")
            }

            UserDefaults.standard.set(profile.id.uuidString, forKey: LocalUserPreferences.Key.activeCalibrationProfileID)
        }

        UserDefaults.standard.set(true, forKey: LocalUserPreferences.Key.hasCompletedCalibration)

        do {
            let settings = try container.settingsRepository.loadSettings()
            settings.tapModeEnabled = false
            try container.settingsRepository.saveSettings(settings)
        } catch {
            logger.warning("Failed to disable tap mode after calibration: \(error.localizedDescription)")
        }

        engine.cancel()
        dismiss()
    }
}
