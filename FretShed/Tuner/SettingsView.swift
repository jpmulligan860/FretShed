// SettingsView.swift
// FretShed

import SwiftUI
import SwiftData

// MARK: - SettingsView

public struct SettingsView: View {

    @Environment(\.appContainer) private var container

    @State private var settings: UserSettings? = nil
    @State private var showDeleteWarning1 = false
    @State private var showDeleteWarning2 = false

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
            .navigationTitle("Settings")
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
            quizSection(settings: settings)
            dataSection
        }
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
            Label("Display", systemImage: "eye")
        }
    }

    // MARK: - Audio Section
    // Covers pitch detection input settings and all sound/haptic output settings.

    private func audioSection(settings: UserSettings) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Detection Confidence")
                    Spacer()
                    Text(String(format: "%.0f%%", settings.confidenceThreshold * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.confidenceThreshold) },
                        set: { settings.confidenceThreshold = Float($0); save(settings) }
                    ),
                    in: 0.70...0.99,
                    step: 0.01
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Note Hold Duration")
                    Spacer()
                    Text("\(settings.noteHoldDurationMs) ms")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.noteHoldDurationMs) },
                        set: { settings.noteHoldDurationMs = Int($0); save(settings) }
                    ),
                    in: 50...200,
                    step: 10
                )
            }

            Toggle("Force Built-In Microphone", isOn: Binding(
                get: { settings.forceBuiltInMic },
                set: { settings.forceBuiltInMic = $0; save(settings) }
            ))

            Toggle("Tap Mode", isOn: Binding(
                get: { settings.tapModeEnabled },
                set: { settings.tapModeEnabled = $0; save(settings) }
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
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.correctSoundVolume) },
                            set: { settings.correctSoundVolume = Float($0); save(settings) }
                        ),
                        in: 0...1,
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
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.metronomeVolume) },
                            set: { settings.metronomeVolume = Float($0); save(settings) }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

        } header: {
            Label("Audio", systemImage: "mic")
        } footer: {
            Text("Higher confidence reduces false notes. Longer hold duration prevents fleeting detections from registering. Tap Mode disables the microphone and lets you self-assess by tapping Correct or Wrong.")
        }
        .animation(.easeInOut(duration: 0.2), value: settings.correctSoundEnabled)
        .animation(.easeInOut(duration: 0.2), value: settings.isMetronomeEnabled)
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
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.defaultTimerDuration) },
                        set: { settings.defaultTimerDuration = Int($0); save(settings) }
                    ),
                    in: 2...20,
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Session Length")
                    Spacer()
                    Text("\(settings.defaultSessionLength) questions")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.defaultSessionLength) },
                        set: { settings.defaultSessionLength = Int($0); save(settings) }
                    ),
                    in: 5...100,
                    step: 5
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hint Timeout")
                    Spacer()
                    Text("\(settings.hintTimeoutSeconds)s")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.hintTimeoutSeconds) },
                        set: { settings.hintTimeoutSeconds = Int($0); save(settings) }
                    ),
                    in: 2...15,
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Set Mastery Threshold")
                    Spacer()
                    Text(String(format: "%.0f%%", settings.masteryThreshold * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { settings.masteryThreshold },
                        set: { settings.masteryThreshold = $0; save(settings) }
                    ),
                    in: 0.70...0.99,
                    step: 0.05
                )
            }
        } header: {
            Label("Quiz Defaults", systemImage: "gamecontroller")
        }
    }

    // MARK: - Data Management Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteWarning1 = true
            } label: {
                HStack {
                    Label("Delete All Data", systemImage: "trash")
                    Spacer()
                }
                .foregroundStyle(.red)
            }
        } header: {
            Label("Data", systemImage: "externaldrive")
        } footer: {
            Text("Removes all sessions, attempts, and mastery scores. Your settings will be kept.")
        }
    }

    // MARK: - Helpers

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
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.appContainer, AppContainer.makeForTesting())
}
