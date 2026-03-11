// SettingsView.swift
// FretShed

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "SettingsView")

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
    @State private var showAudioSetupInfo = false
    @State private var showQuizDefaultsInfo = false
    @State private var showCalibration = false
    @State private var sessionExpanded = true
    @State private var displayExpanded = true
    @State private var licensesExpanded = false
    @State private var developerExpanded = false
    @State private var calibrationProfile: AudioCalibrationProfile? = nil
    @State private var calibrationProfiles: [AudioCalibrationProfile] = []
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var renamingProfile: AudioCalibrationProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var deletingProfile: AudioCalibrationProfile? = nil
    @State private var recalibratingProfile: AudioCalibrationProfile? = nil

    @State private var testDataSeeded = TestDataSeeder.isSeeded
    @State private var showSeedConfirmation = false
    @State private var showRemoveConfirmation = false
    @State private var seedStatusMessage = ""
    @State private var showDeveloperInfo = false
    @State private var showDiagnosticRunner = false

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
            settingsBody
                .toolbar(.hidden, for: .navigationBar)
        }
        .task { await loadSettings() }
    }

    @ViewBuilder
    private var settingsBody: some View {
        if let settings {
            form(settings: settings)
        } else {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                ProgressView("Loading…")
            }
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func form(settings: UserSettings) -> some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(DesignSystem.Typography.screenTitle)
                .foregroundStyle(DesignSystem.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Form {
            audioSetupSection
            quizSection(settings: settings)
            displaySection
            #if DEBUG
            debugSection
            #endif
            licensesSection
        }
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
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
                title: "Global Display",
                items: [
                    ("Note Names", "Choose sharp (A#), flat (Bb), or both (A#/Bb) notation throughout the app."),
                    ("Fretboard Hand", "Flip the fretboard orientation for left-handed players."),
                    ("Default Fret Count", "Number of frets displayed on the fretboard (12, 21, 22, or 24). Also affects heatmap coverage."),
                    ("Appearance", "App color scheme: follow your system setting, or force light or dark mode.")
                ]
            )
        }
        .sheet(isPresented: $showQuizDefaultsInfo) {
            SettingsInfoSheet(
                title: "Session Settings",
                items: [
                    ("Note Acceptance", "Exact String means you must play the right note on the right string. Any String accepts the note wherever you play it on the neck."),
                    ("Tap To Answer", "Tap the fretboard to answer instead of playing. Works best in landscape with 12 frets — gives you bigger tap targets."),
                    ("Haptic Feedback", "A quick vibration lets you know if you got it right or wrong — handy when you're focused on the fretboard."),
                    ("Response Sounds", "Play a sound cue on correct and incorrect answers.")
                ]
            )
        }
        } // VStack
        .background(DesignSystem.Colors.background)
    } // form()

    // MARK: - Display Section

    private var displaySection: some View {
        Section {
            DisclosureGroup(isExpanded: $displayExpanded) {
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
            } label: {
                HStack {
                    DesignSystem.Typography.capsLabel("Global Display")
                    infoButton { showDisplayInfo = true }
                }
            }
        }
        .listRowBackground(DesignSystem.Colors.surface)
    }

    // MARK: - Audio Setup Section

    private var audioSetupSection: some View {
        Section {
            sectionTitleRow("Guitar Rig Settings") { showAudioSetupInfo = true }

            if hasCompletedCalibration, !calibrationProfiles.isEmpty {
                // Add New Profile button
                Button {
                    recalibratingProfile = nil
                    showCalibration = true
                } label: {
                    Label("Add New Profile", systemImage: "plus.circle")
                }

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

                if let s = settings {
                    Toggle("Force Built-In Microphone", isOn: Binding(
                        get: { s.forceBuiltInMic },
                        set: { s.forceBuiltInMic = $0; save(s) }
                    ))
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
        }
        .listRowBackground(DesignSystem.Colors.surface)
        .fullScreenCover(isPresented: $showCalibration, onDismiss: {
            reloadProfiles()
        }) {
            if let profile = recalibratingProfile {
                CalibrationView(isRecalibration: true, recalibratingProfile: profile)
            } else {
                CalibrationView(isRecalibration: hasCompletedCalibration, forceNewProfile: hasCompletedCalibration)
            }
        }
        .sheet(isPresented: $showAudioSetupInfo) {
            SettingsInfoSheet(
                title: "Guitar Rig Settings",
                items: [
                    ("Overview", "Calibration profiles store audio settings per guitar. The active profile is used for note detection in quizzes."),
                    ("Add New Profile", "Create a new calibration profile for a different guitar or input source."),
                    ("Calibration Profiles", "Each profile stores calibration data for a specific guitar and input source. You can have multiple profiles and switch between them. Long-press a profile for options like rename, re-calibrate, or delete."),
                    ("Force Built-In Microphone", "Always use the iPhone's built-in mic, even with an interface or headset plugged in. Try this if detection seems off with your external setup.")
                ]
            )
        }
        .alert("Rename Profile", isPresented: $showRenameAlert) {
            TextField("Profile Name", text: $renameText)
            Button("Save") {
                if let profile = renamingProfile {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.name = trimmed.isEmpty ? nil : trimmed
                    do {
                        try container.calibrationRepository.save(profile)
                    } catch {
                        logger.error("Failed to save renamed profile: \(error.localizedDescription)")
                    }
                    reloadProfiles()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let profile = deletingProfile {
                    do {
                        try container.calibrationRepository.delete(profile)
                    } catch {
                        logger.error("Failed to delete profile: \(error.localizedDescription)")
                    }
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
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundStyle(profile.isActive ? DesignSystem.Colors.amber : DesignSystem.Colors.text2)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(DesignSystem.Typography.bodyLabel)
                    if profile.isActive {
                        Text("Active")
                            .font(DesignSystem.Typography.smallLabel)
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
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            }

            Spacer()
        }
    }

    private func setActiveProfile(_ profile: AudioCalibrationProfile) {
        do {
            try container.calibrationRepository.setActive(profile)
        } catch {
            logger.error("Failed to set active profile: \(error.localizedDescription)")
        }
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
            DisclosureGroup(isExpanded: $sessionExpanded) {
                Picker("Note Acceptance", selection: Binding(
                    get: { settings.defaultNoteAcceptanceMode },
                    set: { settings.defaultNoteAcceptanceMode = $0; save(settings) }
                )) {
                    Text("Exact String").tag(NoteAcceptanceMode.exactString)
                    Text("Any String").tag(NoteAcceptanceMode.anyString)
                }

                Toggle("Tap To Answer", isOn: Binding(
                    get: { settings.tapToAnswerEnabled },
                    set: {
                        settings.tapToAnswerEnabled = $0
                        if $0 { settings.tapModeEnabled = false }
                        save(settings)
                    }
                ))

                Toggle("Haptic Feedback", isOn: Binding(
                    get: { settings.hapticFeedbackEnabled },
                    set: { settings.hapticFeedbackEnabled = $0; save(settings) }
                ))

                Toggle("Response Sounds", isOn: Binding(
                    get: { settings.correctSoundEnabled },
                    set: { settings.correctSoundEnabled = $0; settings.incorrectSoundEnabled = $0; save(settings) }
                ))
            } label: {
                HStack {
                    DesignSystem.Typography.capsLabel("Session Settings")
                    infoButton { showQuizDefaultsInfo = true }
                }
            }
        }
        .listRowBackground(DesignSystem.Colors.surface)
    }


    // MARK: - Debug Section

    private var debugSection: some View {
        Section {
            DisclosureGroup(isExpanded: $developerExpanded) {

            if let s = settings {
                Toggle("Tap Testing Mode", isOn: Binding(
                    get: { s.tapModeEnabled },
                    set: {
                        s.tapModeEnabled = $0
                        if $0 { s.tapToAnswerEnabled = false }
                        save(s)
                    }
                ))
            }

            // Detection tuning (moved from user-facing settings — calibration handles these)
            if let s = settings {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Detection Sensitivity")
                        Spacer()
                        Text(String(format: "%.0f%%", s.confidenceThreshold * 100))
                            .foregroundStyle(DesignSystem.Colors.amber)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(s.confidenceThreshold) },
                            set: { s.confidenceThreshold = Float($0); save(s) }
                        ),
                        range: 0.70...0.99,
                        step: 0.01
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Note Hold Time")
                        Spacer()
                        Text("\(s.noteHoldDurationMs) ms")
                            .foregroundStyle(DesignSystem.Colors.amber)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(s.noteHoldDurationMs) },
                            set: { s.noteHoldDurationMs = Int($0); save(s) }
                        ),
                        range: 50...200,
                        step: 10
                    )
                }
            }

            // Calibration trim sliders
            if let activeProfile = calibrationProfiles.first(where: { $0.isActive }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Input Gain Trim")
                        Spacer()
                        Text(String(format: "%+.1f dB", activeProfile.userGainTrimDB))
                            .foregroundStyle(DesignSystem.Colors.amber)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(activeProfile.userGainTrimDB) },
                            set: {
                                activeProfile.userGainTrimDB = Float($0)
                                do {
                                    try container.calibrationRepository.save(activeProfile)
                                } catch {
                                    logger.error("Failed to save gain trim: \(error.localizedDescription)")
                                }
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
                            .foregroundStyle(DesignSystem.Colors.amber)
                            .monospacedDigit()
                    }
                    GradientSlider(
                        value: Binding(
                            get: { Double(activeProfile.userGateTrimDB) },
                            set: {
                                activeProfile.userGateTrimDB = Float($0)
                                do {
                                    try container.calibrationRepository.save(activeProfile)
                                } catch {
                                    logger.error("Failed to save gate trim: \(error.localizedDescription)")
                                }
                            }
                        ),
                        range: -6...6,
                        step: 0.5
                    )
                }
            }

            // Data management
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

            // Test data
            if testDataSeeded {
                HStack {
                    Label("Test Data Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.correct)
                    Spacer()
                    Text("30 sessions")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }

                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("Remove Test Data", systemImage: "trash")
                }
            } else {
                Button {
                    showSeedConfirmation = true
                } label: {
                    Label("Seed Test Data", systemImage: "square.stack.3d.up.fill")
                }
            }

            if !seedStatusMessage.isEmpty {
                Text(seedStatusMessage)
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.muted)
            }

            // Diagnostics
            Button {
                launchAccuracyAssessment()
            } label: {
                Label("Run Accuracy Assessment", systemImage: "waveform.badge.magnifyingglass")
            }

            Button {
                showDiagnosticRunner = true
            } label: {
                Label("Run 6-String Diagnostic", systemImage: "waveform.badge.mic")
            }
            } label: {
                HStack {
                    DesignSystem.Typography.capsLabel("Developer")
                    infoButton { showDeveloperInfo = true }
                }
            }
        }
        .listRowBackground(DesignSystem.Colors.surface)
        .sheet(isPresented: $showDeveloperInfo) {
            SettingsInfoSheet(
                title: "Developer",
                items: [
                    ("Tap Testing Mode", "Replaces audio detection with Correct/Wrong buttons on screen. Useful for practicing note recognition without your guitar."),
                    ("Detection Sensitivity", "How sure FretShed needs to be before it accepts a note. Calibration handles this — only tweak for testing."),
                    ("Note Hold Time", "How long a note must ring before it counts. Usually handled automatically — for testing only."),
                    ("Input Gain Trim", "Fine-tune the input sensitivity for the active calibration profile. Increase if notes aren't being detected; decrease if you're getting false detections."),
                    ("Noise Gate Trim", "Adjust the noise gate threshold for the active calibration profile. Increase in noisy environments; decrease in quiet ones."),
                    ("Back Up Data", "Exports all sessions, attempts, mastery scores, settings, and calibration profiles to a JSON file. The file is saved to your Documents folder and accessible via the Files app."),
                    ("Restore from Backup", "Imports a previously exported backup file. This replaces all current data — sessions, mastery scores, calibration profiles, and settings — with the backup contents."),
                    ("Delete All Data", "Permanently removes all session history, mastery scores, and attempts. Calibration profiles and settings are kept. This cannot be undone."),
                    ("Test Data", "Seeds 30 sessions (5 per focus mode) with realistic accuracy trends (~48%→86%), improving response times, and all 4 mastery tiers on the heatmap. Remove before TestFlight."),
                    ("Accuracy Assessment", "Runs through every fretboard cell 3 times to measure detection accuracy across the full fretboard."),
                    ("6-String Diagnostic", "Records per-frame Goertzel and YIN data for all 6 open strings and copies a diagnostic report to the clipboard.")
                ]
            )
        }
        .fullScreenCover(isPresented: $showDiagnosticRunner) {
            DiagnosticRunnerView()
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
        .alert("Seed Test Data?", isPresented: $showSeedConfirmation) {
            Button("Seed") {
                TestDataSeeder.seed(container: container)
                testDataSeeded = TestDataSeeder.isSeeded
                seedStatusMessage = testDataSeeded ? "Done — 30 sessions seeded" : "Failed"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create 30 sessions across all focus modes with realistic accuracy trends and mastery scores.")
        }
        .alert("Remove Test Data?", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                TestDataSeeder.remove(container: container)
                testDataSeeded = TestDataSeeder.isSeeded
                seedStatusMessage = !testDataSeeded ? "Test data removed" : "Failed"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all test sessions and rebuild mastery scores.")
        }
    }

    // MARK: - Licenses Section

    private var licensesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $licensesExpanded) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Montserrat")
                        .font(DesignSystem.Typography.bodyLabel)
                    Text("Designed by Julieta Ulanovsky. Licensed under the SIL Open Font License.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Crimson Pro")
                        .font(DesignSystem.Typography.bodyLabel)
                    Text("Designed by Jacques Le Bailly. Licensed under the SIL Open Font License.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("JetBrains Mono")
                        .font(DesignSystem.Typography.bodyLabel)
                    Text("Designed by JetBrains. Licensed under the Apache License 2.0.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            } label: {
                DesignSystem.Typography.capsLabel("Licenses")
            }
            .tint(DesignSystem.Colors.text2)
        }
        .listRowBackground(DesignSystem.Colors.surface)
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
        do {
            settings = try container.settingsRepository.loadSettings()
        } catch {
            logger.warning("Settings load failed, retrying: \(error.localizedDescription)")
            // Retry once after a brief delay to handle app-startup race conditions
            // where SwiftData's model container hasn't fully initialised yet.
            try? await Task.sleep(for: .milliseconds(300))
            do {
                settings = try container.settingsRepository.loadSettings()
            } catch {
                logger.error("Settings load failed on retry: \(error.localizedDescription)")
            }
        }
    }

    private func save(_ settings: UserSettings) {
        do {
            try container.settingsRepository.saveSettings(settings)
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
        }
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

    // MARK: - Section Helpers

    private func sectionTitleRow(_ title: String, infoAction: @escaping () -> Void) -> some View {
        HStack {
            DesignSystem.Typography.capsLabel(title)
            infoButton(action: infoAction)
            Spacer()
        }
    }

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(DesignSystem.Typography.smallLabel)
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
                                .font(DesignSystem.Typography.bodyLabel)
                            Text(description)
                                .font(DesignSystem.Typography.smallLabel)
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
