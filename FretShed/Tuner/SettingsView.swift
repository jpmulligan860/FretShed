// SettingsView.swift
// FretShed

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

public struct SettingsView: View {

    @Environment(\.appContainer) private var container

    @State private var settings: UserSettings? = nil
    @State private var showDeleteWarning1 = false
    @State private var showDeleteWarning2 = false
    @State private var showBackupSuccess = false
    @State private var backupFileURL: URL? = nil
    @State private var showBackupError = false
    @State private var backupErrorMessage = ""
    @State private var showFileImporter = false
    @State private var showRestoreWarning = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var showRestoreSuccess = false
    @State private var restoreResult: BackupImportResult? = nil

    @State private var showDisplayInfo = false
    @State private var showAudioInfo = false
    @State private var showAudioSetupInfo = false
    @State private var showQuizDefaultsInfo = false
    @State private var showDataInfo = false
    @State private var showCalibration = false
    @State private var calibrationProfile: AudioCalibrationProfile? = nil
    @State private var calibrationProfiles: [AudioCalibrationProfile] = []
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renamingProfile: AudioCalibrationProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var deletingProfile: AudioCalibrationProfile? = nil
    @State private var recalibratingProfile: AudioCalibrationProfile? = nil

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteNameFormatRaw: String = LocalUserPreferences.Default.noteNameFormat

    @AppStorage(LocalUserPreferences.Key.fretboardOrientation)
    private var fretboardOrientationRaw: String = LocalUserPreferences.Default.fretboardOrientation

    @AppStorage(LocalUserPreferences.Key.defaultFretCount)
    private var defaultFretCountRaw: Int = LocalUserPreferences.Default.defaultFretCount

    @AppStorage(LocalUserPreferences.Key.colorScheme)
    private var colorSchemeRaw: String = LocalUserPreferences.Default.colorScheme

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let settings {
                    form(settings: settings)
                } else {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await loadSettings() }
    }

    // MARK: - Form

    @ViewBuilder
    private func form(settings: UserSettings) -> some View {
        Form {
            displaySection
            audioSection(settings: settings)
            audioSetupSection
            quizSection(settings: settings)
            dataSection
            licensesSection
        }
        .tint(DesignSystem.Colors.amber)
        .alert("Delete All Data?", isPresented: $showDeleteWarning1) {
            Button("Continue with Delete", role: .destructive) {
                showDeleteWarning2 = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all sessions, attempts, and mastery scores. Your settings will not be affected.")
        }
        .alert("Are You Sure?", isPresented: $showDeleteWarning2) {
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. All progress, sessions, and mastery data will be permanently erased.")
        }
        .sheet(isPresented: $showDisplayInfo) {
            SettingsInfoSheet(
                title: "Display",
                items: [
                    ("Note Names", "Choose between sharp (A#) or flat (Bb) notation."),
                    ("Fretboard Hand", "Flip the fretboard display for left-handed players."),
                    ("Default Fret Count", "Number of frets shown on the fretboard (12, 21, 22, or 24)."),
                    ("Appearance", "App color scheme: follow system setting, or force light/dark.")
                ]
            )
        }
        .sheet(isPresented: $showAudioInfo) {
            SettingsInfoSheet(
                title: "Audio",
                items: [
                    ("Detection Sensitivity", "How certain the pitch detector must be before accepting a note. Higher = fewer false detections but requires cleaner playing."),
                    ("Note Hold Time", "How long a note must be held before it's accepted. Prevents fleeting detections from triggering wrong answers."),
                    ("Force Built-In Microphone", "Always use the iPhone mic even when an external audio device is connected."),
                    ("Tap Testing Mode", "Disable microphone detection and use Correct/Wrong buttons instead. Use this to test yourself when you don't have your guitar handy."),
                    ("Tap To Answer", "Tap directly on the fretboard to choose your answer instead of playing a note. For best results, use landscape orientation with Default Fret Count set to 12 so the fretboard positions are large enough to tap accurately."),
                    ("Response Sounds", "Play a sound effect on correct and incorrect answers."),
                    ("Response Sound Volume", "Volume level for correct/incorrect sound effects."),
                    ("Metronome in Quiz", "Play a countdown tick during timed quiz sessions."),
                    ("Metronome Volume", "Volume level for the countdown tick.")
                ]
            )
        }
        .sheet(isPresented: $showQuizDefaultsInfo) {
            SettingsInfoSheet(
                title: "Quiz Defaults",
                items: [
                    ("Default Focus Mode", "The starting focus mode when launching a new session. Choose a default from the dropdown list"),
                    ("String Selection", "Which string should be pre-selected for Single String mode."),
                    ("Note Highlighting", "How target notes are shown: always visible, revealed after playing, or show all positions."),
                    ("Note Acceptance", "Accept the correct note on any string, or require the exact string shown."),
                    ("Timer Duration", "Seconds per question in Timed mode."),
                    ("Session Length", "Number of questions per session (except Streak mode)."),
                    ("Hint Timeout", "Seconds before the fret hint is automatically shown."),
                    ("Set Mastery Threshold", "Accuracy percentage needed to mark a cell as mastered.")
                ]
            )
        }
        .sheet(isPresented: $showDataInfo) {
            SettingsInfoSheet(
                title: "Data",
                items: [
                    ("Back Up Data", "Exports all sessions, attempts, mastery scores, settings, and calibration profile to a JSON file in the Documents folder."),
                    ("Restore from Backup", "Imports a previously exported backup file. Replaces all current data with the backup contents."),
                    ("Delete All Data", "Permanently removes all session history, mastery scores, and attempts. This cannot be undone.")
                ]
            )
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        Section {
            Picker("Note Names", selection: $noteNameFormatRaw) {
                ForEach(NoteNameFormat.allCases, id: \.rawValue) { format in
                    Text(format.localizedLabel).tag(format.rawValue)
                }
            }

            Picker("Fretboard Hand", selection: $fretboardOrientationRaw) {
                Text("Right-Handed").tag(FretboardOrientation.rightHand.rawValue)
                Text("Left-Handed").tag(FretboardOrientation.leftHand.rawValue)
            }

            Picker("Default Fret Count", selection: $defaultFretCountRaw) {
                ForEach(DefaultFretCount.allCases, id: \.rawValue) { count in
                    Text(count.label).tag(count.rawValue)
                }
            }

            Picker("Appearance", selection: $colorSchemeRaw) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        } header: {
            HStack {
                DesignSystem.Typography.capsLabel("Display")
                infoButton { showDisplayInfo = true }
            }
        }
    }

    // MARK: - Audio Section
    // Covers pitch detection input settings and all sound/haptic output settings.

    private func audioSection(settings: UserSettings) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Detection Sensitivity")
                    Spacer()
                    Text(String(format: "%.0f%%", settings.confidenceThreshold * 100))
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { Double(settings.confidenceThreshold) },
                        set: { settings.confidenceThreshold = Float($0); save(settings) }
                    ),
                    range: 0.70...0.99,
                    step: 0.01
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Note Hold Time")
                    Spacer()
                    Text("\(settings.noteHoldDurationMs) ms")
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { Double(settings.noteHoldDurationMs) },
                        set: { settings.noteHoldDurationMs = Int($0); save(settings) }
                    ),
                    range: 50...200,
                    step: 10
                )
            }

            Toggle("Force Built-In Microphone", isOn: Binding(
                get: { settings.forceBuiltInMic },
                set: { settings.forceBuiltInMic = $0; save(settings) }
            ))

            Toggle("Tap Testing Mode", isOn: Binding(
                get: { settings.tapModeEnabled },
                set: {
                    settings.tapModeEnabled = $0
                    if $0 { settings.tapToAnswerEnabled = false }
                    save(settings)
                }
            ))

            Toggle("Tap To Answer", isOn: Binding(
                get: { settings.tapToAnswerEnabled },
                set: {
                    settings.tapToAnswerEnabled = $0
                    if $0 { settings.tapModeEnabled = false }
                    save(settings)
                }
            ))

            Toggle("Response Sounds", isOn: Binding(
                get: { settings.correctSoundEnabled },
                set: { settings.correctSoundEnabled = $0; settings.incorrectSoundEnabled = $0; save(settings) }
            ))

            if settings.correctSoundEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Response Sound Volume")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.correctSoundVolume * 100))
                            .foregroundStyle(DesignSystem.Colors.text2)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(settings.correctSoundVolume) },
                            set: { settings.correctSoundVolume = Float($0); save(settings) }
                        ),
                        range: 0...1,
                        step: 0.05
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Toggle("Metronome in Quiz", isOn: Binding(
                get: { settings.isMetronomeEnabled },
                set: { settings.isMetronomeEnabled = $0; save(settings) }
            ))

            if settings.isMetronomeEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Metronome Volume")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.metronomeVolume * 100))
                            .foregroundStyle(DesignSystem.Colors.text2)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(settings.metronomeVolume) },
                            set: { settings.metronomeVolume = Float($0); save(settings) }
                        ),
                        range: 0...1,
                        step: 0.05
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

        } header: {
            HStack {
                DesignSystem.Typography.capsLabel("Audio")
                infoButton { showAudioInfo = true }
            }
        } footer: {
            Text("Higher confidence reduces false notes. Longer hold duration prevents fleeting detections from registering. Tap Testing Mode disables the microphone and lets you self-assess by tapping Correct or Wrong. Tap To Answer lets you tap the fretboard directly to identify note positions.")
        }
        .animation(.easeInOut(duration: 0.2), value: settings.correctSoundEnabled)
        .animation(.easeInOut(duration: 0.2), value: settings.isMetronomeEnabled)
    }

    // MARK: - Audio Setup Section

    private var audioSetupSection: some View {
        Section {
            if hasCompletedCalibration, !calibrationProfiles.isEmpty {
                // Profile list
                ForEach(calibrationProfiles, id: \.id) { profile in
                    profileRow(profile)
                        .contextMenu {
                            if !profile.isActive {
                                Button {
                                    setActiveProfile(profile)
                                } label: {
                                    Label("Set Active", systemImage: "checkmark.circle")
                                }
                            }
                            Button {
                                renamingProfile = profile
                                renameText = profile.name ?? ""
                                showRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button {
                                recalibratingProfile = profile
                                showCalibration = true
                            } label: {
                                Label("Re-Calibrate", systemImage: "arrow.clockwise")
                            }
                            Button(role: .destructive) {
                                deletingProfile = profile
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deletingProfile = profile
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !profile.isActive {
                                Button {
                                    setActiveProfile(profile)
                                } label: {
                                    Label("Set Active", systemImage: "checkmark.circle")
                                }
                                .tint(DesignSystem.Colors.correct)
                            }
                        }
                }

                // Trim sliders for active profile
                if let activeProfile = calibrationProfiles.first(where: { $0.isActive }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Input Gain Trim")
                            Spacer()
                            Text(String(format: "%+.1f dB", activeProfile.userGainTrimDB))
                                .foregroundStyle(DesignSystem.Colors.text2)
                                .monospacedDigit()
                        }
                        GradientSlider(
                            value: Binding(
                                get: { Double(activeProfile.userGainTrimDB) },
                                set: {
                                    activeProfile.userGainTrimDB = Float($0)
                                    try? container.calibrationRepository.save(activeProfile)
                                }
                            ),
                            range: -6...6,
                            step: 0.5
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Noise Gate Trim")
                            Spacer()
                            Text(String(format: "%+.1f dB", activeProfile.userGateTrimDB))
                                .foregroundStyle(DesignSystem.Colors.text2)
                                .monospacedDigit()
                        }
                        GradientSlider(
                            value: Binding(
                                get: { Double(activeProfile.userGateTrimDB) },
                                set: {
                                    activeProfile.userGateTrimDB = Float($0)
                                    try? container.calibrationRepository.save(activeProfile)
                                }
                            ),
                            range: -6...6,
                            step: 0.5
                        )
                    }
                }

                // Add New Profile button
                Button {
                    recalibratingProfile = nil
                    showCalibration = true
                } label: {
                    Label("Add New Profile", systemImage: "plus.circle")
                }

                if settings?.showAccuracyAssessment != false {
                    Button {
                        launchAccuracyAssessment()
                    } label: {
                        Label("Run Accuracy Assessment", systemImage: "waveform.badge.magnifyingglass")
                    }
                }
            } else {
                // Not calibrated
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Not Done")
                        .foregroundStyle(DesignSystem.Colors.amber)
                }

                Button {
                    recalibratingProfile = nil
                    showCalibration = true
                } label: {
                    Label("Run Calibration", systemImage: "waveform.badge.mic")
                }
            }
        } header: {
            HStack {
                DesignSystem.Typography.capsLabel("Audio Setup")
                infoButton { showAudioSetupInfo = true }
            }
        } footer: {
            Text("Calibration profiles store audio settings per guitar. The active profile is used for note detection in quizzes.")
        }
        .fullScreenCover(isPresented: $showCalibration, onDismiss: {
            reloadProfiles()
        }) {
            if let profile = recalibratingProfile {
                CalibrationView(isRecalibration: true, recalibratingProfile: profile)
            } else {
                CalibrationView(isRecalibration: hasCompletedCalibration)
            }
        }
        .sheet(isPresented: $showAudioSetupInfo) {
            SettingsInfoSheet(
                title: "Audio Setup",
                items: [
                    ("Calibration Profiles", "Each profile stores calibration data for a specific guitar and input source. You can have multiple profiles and switch between them."),
                    ("Input Gain Trim", "Fine-tune the input sensitivity for the active profile. Increase if notes aren't being detected; decrease if you're getting false detections."),
                    ("Noise Gate Trim", "Adjust the noise gate threshold for the active profile. Increase in noisy environments; decrease in quiet ones.")
                ]
            )
        }
        .alert("Rename Profile", isPresented: $showRenameAlert) {
            TextField("Profile Name", text: $renameText)
            Button("Save") {
                if let profile = renamingProfile {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.name = trimmed.isEmpty ? nil : trimmed
                    try? container.calibrationRepository.save(profile)
                    reloadProfiles()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let profile = deletingProfile {
                    try? container.calibrationRepository.delete(profile)
                    reloadProfiles()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if calibrationProfiles.count <= 1 {
                Text("This is your only calibration profile. Deleting it will require you to re-calibrate before using audio detection.")
            } else {
                Text("This profile will be permanently deleted.")
            }
        }
        .task {
            reloadProfiles()
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: AudioCalibrationProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: profile.guitarType?.iconName ?? "guitars")
                .font(.title3)
                .foregroundStyle(profile.isActive ? DesignSystem.Colors.cherry : DesignSystem.Colors.text2)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.subheadline.weight(.semibold))
                    if profile.isActive {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.correct.opacity(0.2), in: Capsule())
                            .foregroundStyle(DesignSystem.Colors.correct)
                    }
                }
                HStack(spacing: 8) {
                    if let guitarType = profile.guitarType {
                        Text(guitarType.displayName)
                    }
                    Text(profile.inputSource.displayName)
                    HStack(spacing: 2) {
                        Circle()
                            .fill(qualityBadgeColor(profile.signalQualityScore))
                            .frame(width: 6, height: 6)
                        Text("\(Int(profile.signalQualityScore * 100))%")
                    }
                }
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.text2)
            }

            Spacer()
        }
    }

    private func setActiveProfile(_ profile: AudioCalibrationProfile) {
        try? container.calibrationRepository.setActive(profile)
        reloadProfiles()
    }

    private func reloadProfiles() {
        calibrationProfiles = (try? container.calibrationRepository.allProfiles()) ?? []
        calibrationProfile = calibrationProfiles.first(where: { $0.isActive }) ?? calibrationProfiles.first
    }

    private func qualityBadgeColor(_ score: Float) -> Color {
        if score >= 0.8 { return DesignSystem.Colors.correct }
        if score >= 0.5 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    // MARK: - Quiz Defaults Section

    private func quizSection(settings: UserSettings) -> some View {
        Section {
            Picker("Default Focus Mode", selection: Binding(
                get: { settings.defaultGameMode },
                set: { settings.defaultGameMode = $0; save(settings) }
            )) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Text(mode.localizedLabel).tag(mode)
                }
            }

            Picker("String Selection", selection: Binding(
                get: { settings.defaultStringOrdering },
                set: { settings.defaultStringOrdering = $0; save(settings) }
            )) {
                ForEach(StringOrdering.allCases, id: \.self) { order in
                    Text(order.localizedLabel).tag(order)
                }
            }

            Picker("Note Highlighting", selection: Binding(
                get: { settings.defaultNoteHighlighting },
                set: { settings.defaultNoteHighlighting = $0; save(settings) }
            )) {
                Text("Single Position").tag(NoteHighlighting.singlePosition)
                Text("All Positions").tag(NoteHighlighting.allPositions)
                Text("Reveal After").tag(NoteHighlighting.singleThenReveal)
            }

            Picker("Note Acceptance", selection: Binding(
                get: { settings.defaultNoteAcceptanceMode },
                set: { settings.defaultNoteAcceptanceMode = $0; save(settings) }
            )) {
                Text("Exact String").tag(NoteAcceptanceMode.exactString)
                Text("Any String").tag(NoteAcceptanceMode.anyString)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Timer Duration")
                    Spacer()
                    Text("\(settings.defaultTimerDuration)s")
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { Double(settings.defaultTimerDuration) },
                        set: { settings.defaultTimerDuration = Int($0); save(settings) }
                    ),
                    range: 2...20,
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Session Length")
                    Spacer()
                    Text("\(settings.defaultSessionLength) questions")
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { Double(settings.defaultSessionLength) },
                        set: { settings.defaultSessionLength = Int($0); save(settings) }
                    ),
                    range: 5...100,
                    step: 5
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hint Timeout")
                    Spacer()
                    Text("\(settings.hintTimeoutSeconds)s")
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { Double(settings.hintTimeoutSeconds) },
                        set: { settings.hintTimeoutSeconds = Int($0); save(settings) }
                    ),
                    range: 2...15,
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Set Mastery Threshold")
                    Spacer()
                    Text(String(format: "%.0f%%", settings.masteryThreshold * 100))
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                }
                GradientSlider(
                    value: Binding(
                        get: { settings.masteryThreshold },
                        set: { settings.masteryThreshold = $0; save(settings) }
                    ),
                    range: 0.70...0.99,
                    step: 0.05
                )
            }
        } header: {
            HStack {
                DesignSystem.Typography.capsLabel("Quiz Defaults")
                infoButton { showQuizDefaultsInfo = true }
            }
        }
    }

    // MARK: - Data Management Section

    private var dataSection: some View {
        Section {
            Button {
                performBackup()
            } label: {
                HStack {
                    Label("Back Up Data", systemImage: "square.and.arrow.up")
                    Spacer()
                }
            }

            Button {
                showFileImporter = true
            } label: {
                HStack {
                    Label("Restore from Backup", systemImage: "square.and.arrow.down")
                    Spacer()
                }
            }

            Button(role: .destructive) {
                showDeleteWarning1 = true
            } label: {
                HStack {
                    Label("Delete All Data", systemImage: "trash")
                    Spacer()
                }
                .foregroundStyle(DesignSystem.Colors.wrong)
            }
        } header: {
            HStack {
                DesignSystem.Typography.capsLabel("Data")
                infoButton { showDataInfo = true }
            }
        } footer: {
            Text("Back up your sessions, mastery scores, and settings to a JSON file. Restore replaces all current data with the backup.")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pendingRestoreURL = url
                showRestoreWarning = true
            case .failure(let error):
                backupErrorMessage = error.localizedDescription
                showBackupError = true
            }
        }
        .alert("Back Up Successful", isPresented: $showBackupSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            if let url = backupFileURL {
                Text("Saved to \(url.lastPathComponent). You can access it in the Files app under FretShed.")
            }
        }
        .alert("Backup Error", isPresented: $showBackupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupErrorMessage)
        }
        .alert("Restore from Backup?", isPresented: $showRestoreWarning) {
            Button("Replace All Data", role: .destructive) {
                performRestore()
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text("This will replace all current sessions, mastery scores, and attempts with the backup data. This cannot be undone.")
        }
        .alert("Restore Successful", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = restoreResult {
                Text("\(result.sessionsRestored) sessions, \(result.attemptsRestored) attempts, \(result.masteryScoresRestored) mastery scores restored."
                     + (result.settingsRestored ? " Settings restored." : "")
                     + (result.calibrationRestored ? " Calibration restored." : ""))
            }
        }
    }

    // MARK: - Licenses Section

    private var licensesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Montserrat")
                    .font(.subheadline.weight(.semibold))
                Text("Designed by Julieta Ulanovsky. Licensed under the SIL Open Font License.")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Crimson Pro")
                    .font(.subheadline.weight(.semibold))
                Text("Designed by Jacques Le Bailly. Licensed under the SIL Open Font License.")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("JetBrains Mono")
                    .font(.subheadline.weight(.semibold))
                Text("Designed by JetBrains. Licensed under the Apache License 2.0.")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        } header: {
            DesignSystem.Typography.capsLabel("Licenses")
        }
    }

    // MARK: - Helpers

    private func performBackup() {
        let manager = BackupManager(container: container)
        do {
            let url = try manager.exportBackup()
            backupFileURL = url
            showBackupSuccess = true
        } catch {
            backupErrorMessage = error.localizedDescription
            showBackupError = true
        }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        let manager = BackupManager(container: container)
        do {
            let result = try manager.importBackup(from: url)
            restoreResult = result
            showRestoreSuccess = true
            // Reload settings and profiles in the view
            settings = try? container.settingsRepository.loadSettings()
            reloadProfiles()
        } catch {
            backupErrorMessage = error.localizedDescription
            showBackupError = true
        }
        pendingRestoreURL = nil
    }

    private func deleteAllData() {
        do {
            try container.sessionRepository.deleteAll()
            try container.attemptRepository.deleteAll()
            try container.masteryRepository.deleteAll()
        } catch {
            // Silently fail — data layer should handle errors gracefully.
        }
    }

    private func loadSettings() async {
        // Load from the repository so the returned object is tracked by SwiftData.
        // Do NOT fall back to a bare UserSettings() — that creates a detached object
        // whose mutations are never persisted.
        settings = try? container.settingsRepository.loadSettings()
        if settings == nil {
            // Retry once after a brief delay to handle app-startup race conditions
            // where SwiftData's model container hasn't fully initialised yet.
            try? await Task.sleep(for: .milliseconds(300))
            settings = try? container.settingsRepository.loadSettings()
        }
        if let s = settings {
            NotificationScheduler.shared.sync(settings: s)
        }
    }

    private func save(_ settings: UserSettings) {
        try? container.settingsRepository.saveSettings(settings)
    }

    private func launchAccuracyAssessment() {
        let fretEnd = defaultFretCountRaw  // matches user's chosen fret count (12, 21, 22, or 24)
        let session = Session(
            focusMode: .accuracyAssessment,
            gameMode: .untimed,
            fretRangeStart: 0,
            fretRangeEnd: fretEnd,
            isAdaptive: false
        )
        Task { @MainActor in
            try? container.sessionRepository.save(session)
            let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
            let vm = QuizViewModel(
                session: session,
                fretboardMap: container.fretboardMap,
                settings: settings,
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                attemptRepository: container.attemptRepository
            )
            NotificationCenter.default.post(name: .launchQuiz, object: vm)
        }
    }

    // MARK: - Info Button

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
    }
}

// MARK: - SettingsInfoSheet

private struct SettingsInfoSheet: View {

    let title: String
    let items: [(String, String)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.0) { label, description in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.text2)
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.appContainer, AppContainer.makeForTesting())
}
