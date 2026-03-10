// SessionSetupView.swift
// FretShed — Presentation Layer
//
// Compact session configuration sheet.
// Designed to fit on screen without scrolling.

import SwiftUI

public struct SessionSetupView: View {

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @State private var selectedFocusMode: FocusMode = .fullFretboard
    @State private var selectedGameMode: GameMode = .untimed
    @State private var selectedStrings: Set<Int> = [6]
    @State private var selectedNote: MusicalNote = .e
    @State private var sessionLength: Int = 20
    @State private var noteVisibility: NoteVisibility = .hiddenUntilAnswered
    @State private var timerDuration: Int = 10
    @State private var selectedFrets: Set<Int> = [5, 6, 7, 8]
    // Chord progression state
    @State private var selectedPresetIndex: Int? = 0          // nil = custom
    @State private var customProgression: ChordProgression = .customTemplate()
    @State private var progressionKey: MusicalNote = .c
    @State private var chordToneSelection: ChordToneSelection = .closeTriad
    @State private var chordPositionEnabled = false
    @State private var chordStringGroup: [Int] = []    // empty = all strings
    @State private var circleConstraint: CircleConstraint = .fullFretboard
    @State private var showPracticeModeInfo = false
    @State private var showFocusModeInfo = false
    @State private var showChordProgressionInfo = false

    enum CircleConstraint: String, CaseIterable {
        case fullFretboard, strings, position

        var label: String {
            switch self {
            case .fullFretboard: return "Full Fretboard"
            case .strings:       return "Strings"
            case .position:      return "Position"
            }
        }
    }

    public init() {}

    /// True when the device is in a landscape / wide layout (e.g. iPhone landscape or iPad).
    private var isWide: Bool {
        vSizeClass == .compact || hSizeClass == .regular
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Custom header matching app-wide style
            HStack {
                Text("My Custom Session")
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(DesignSystem.Colors.text)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Group {
                if isWide {
                    wideLayout
                } else {
                    compactLayout
                }
            }
            .sheet(isPresented: $showPracticeModeInfo) {
                PracticeModeInfoSheet()
            }
            .sheet(isPresented: $showFocusModeInfo) {
                FocusModeInfoSheet()
            }
            .sheet(isPresented: $showChordProgressionInfo) {
                ChordProgressionInfoSheet()
            }
            .task {
                // Initialise UI from persisted default settings so the user sees
                // their saved session length and game mode rather than hard-coded defaults.
                if let s = try? container.settingsRepository.loadSettings() {
                    sessionLength    = s.defaultSessionLength
                    selectedGameMode = s.defaultGameMode
                    noteVisibility   = s.noteVisibility
                    timerDuration    = s.defaultTimerDuration
                }
            }
        }
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Compact Layout (portrait iPhone)

    private var compactLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Practice Mode card
                    VStack(spacing: 12) {
                        gameModeSection
                        sessionLengthSection
                        if selectedGameMode == .timed {
                            timerDurationSection
                        }
                        noteVisibilitySection
                    }
                    .padding(.vertical, 16)
                    .woodshopCard()
                    .padding(.horizontal, 20)

                    // Focus Mode card
                    VStack(spacing: 12) {
                        focusModeSection

                        if selectedFocusMode == .singleString {
                            stringPickerSection
                        }

                        if selectedFocusMode == .singleNote {
                            notePickerSection
                        }

                        if selectedFocusMode == .fretboardPosition {
                            fretPickerSection
                        }

                        if selectedFocusMode == .chordProgression {
                            chordProgressionSection
                        }

                        if isCircleMode {
                            circleConstraintSection

                            if circleConstraint == .strings {
                                stringPickerSection
                            }

                            if circleConstraint == .position {
                                fretPickerSection
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .woodshopCard()
                    .padding(.horizontal, 20)

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Custom Session:")
                            .font(DesignSystem.Typography.sectionHeader)
                            .foregroundStyle(DesignSystem.Colors.text)
                            .padding(.horizontal, 20)

                        descriptionCard
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedFocusMode)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }

            startButton
                .padding(.vertical, 12)
        }
    }

    // MARK: - Wide Layout (landscape iPhone / iPad)

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column: mode pickers
            ScrollView {
                VStack(spacing: 16) {
                    // Practice Mode card
                    VStack(spacing: 12) {
                        gameModeSection
                        sessionLengthSection
                        if selectedGameMode == .timed {
                            timerDurationSection
                        }
                        noteVisibilitySection
                    }
                    .padding(.vertical, 16)
                    .woodshopCard()
                    .padding(.horizontal, 20)

                    // Focus Mode card
                    VStack(spacing: 12) {
                        focusModeSection

                        if selectedFocusMode == .singleString {
                            stringPickerSection
                        }

                        if selectedFocusMode == .singleNote {
                            notePickerSection
                        }

                        if selectedFocusMode == .fretboardPosition {
                            fretPickerSection
                        }

                        if selectedFocusMode == .chordProgression {
                            chordProgressionSection
                        }

                        if isCircleMode {
                            circleConstraintSection

                            if circleConstraint == .strings {
                                stringPickerSection
                            }

                            if circleConstraint == .position {
                                fretPickerSection
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .woodshopCard()
                    .padding(.horizontal, 20)

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Custom Session:")
                            .font(DesignSystem.Typography.sectionHeader)
                            .foregroundStyle(DesignSystem.Colors.text)
                            .padding(.horizontal, 20)

                        descriptionCard
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedFocusMode)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right column: start button centred
            VStack {
                Spacer()
                startButton
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: 260)
        }
    }

    // MARK: - Shared Sub-Views

    private var focusModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Focus Mode", systemImage: "scope")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Button {
                    showFocusModeInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                ForEach(displayedFocusModes, id: \.self) { mode in
                    FocusModeChip(
                        mode: mode,
                        isSelected: selectedFocusMode == mode,
                        isPremium: !mode.isFreeMode
                    ) {
                        if mode.isFreeMode {
                            selectedFocusMode = mode
                        } else {
                            // Premium modes — visual-only lock until Phase 4 paywall
                            selectedFocusMode = mode
                        }
                        if isCircleMode {
                            circleConstraint = .fullFretboard
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Practice Mode", systemImage: "metronome")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Button {
                    showPracticeModeInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(GameMode.selectableCases, id: \.self) { mode in
                    GameModeChip(
                        mode: mode,
                        isSelected: selectedGameMode == mode
                    ) {
                        selectedGameMode = mode
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var descriptionCard: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Practice Mode", value: selectedGameMode.localizedLabel)
            if selectedGameMode == .timed {
                summaryDivider
                summaryRow(label: "Timer", value: "\(timerDuration)s per question")
            }
            summaryDivider
            summaryRow(label: "Questions", value: "\(sessionLength)")
            summaryDivider
            summaryRow(label: "Notes", value: noteVisibility.displayLabel)
            summaryDivider
            summaryRow(label: "Focus", value: selectedFocusMode.localizedLabel)

            if selectedFocusMode == .singleString {
                summaryDivider
                summaryRow(label: "Strings", value: selectedStrings.sorted().map { "Str \($0)" }.joined(separator: ", "))
            }

            if selectedFocusMode == .singleNote {
                summaryDivider
                summaryRow(label: "Note", value: selectedNote.displayName(format: .sharps))
            }

            if selectedFocusMode == .fretboardPosition {
                summaryDivider
                let frets = selectedFrets.sorted()
                summaryRow(label: "Frets", value: frets.isEmpty ? "None" : "Frets \(frets.first!)–\(frets.last!)")
            }

            if selectedFocusMode == .chordProgression {
                summaryDivider
                let progName: String = {
                    guard let idx = selectedPresetIndex,
                          ChordProgression.presets.indices.contains(idx) else { return "Custom" }
                    return ChordProgression.presets[idx].name
                }()
                summaryRow(label: "Progression", value: "\(progressionKey.displayName(format: .sharps)) \(progName)")
            }

            if isCircleMode {
                summaryDivider
                summaryRow(label: "Constraint", value: circleConstraint.label)
            }
        }
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var summaryDivider: some View {
        Divider().padding(.horizontal, 16)
    }

    private var isCircleMode: Bool {
        selectedFocusMode == .circleOfFourths || selectedFocusMode == .circleOfFifths
    }

    private var circleConstraintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Circle Constraint", systemImage: "scope")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .padding(.horizontal, 20)

            Picker("Constraint", selection: $circleConstraint) {
                ForEach(CircleConstraint.allCases, id: \.self) { c in
                    Text(c.label).tag(c)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
        }
    }

    private var startButton: some View {
        Button {
            startSession()
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Practice")
                    .font(DesignSystem.Typography.bodyLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    private var stringPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Strings", systemImage: "minus")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Spacer()
                // "All" shortcut
                Button("All") {
                    selectedStrings = [1, 2, 3, 4, 5, 6]
                }
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                // Display from 6 (low E) to 1 (high e).
                ForEach([6, 5, 4, 3, 2, 1], id: \.self) { string in
                    let isSelected = selectedStrings.contains(string)
                    Button {
                        if isSelected {
                            if selectedStrings.count > 1 {
                                selectedStrings.remove(string)
                            }
                        } else {
                            selectedStrings.insert(string)
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(string)")
                                .font(DesignSystem.Typography.bodyLabel)
                            Text(Self.stringNoteName(string))
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .padding(.horizontal, 20)

            // Summary label showing which strings are active
            Text(selectedStringsSummary)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.2), value: selectedStrings)
        }
    }

    private var selectedStringsSummary: String {
        if selectedStrings.count == 6 { return "All strings" }
        let sorted = selectedStrings.sorted(by: >)   // 6 (low E) first
        let names = sorted.map { "\($0)/\(Self.stringNoteName($0))" }
        return names.joined(separator: ", ")
    }

    /// Open-string note name for each string number (standard tuning).
    private static func stringNoteName(_ string: Int) -> String {
        switch string {
        case 1: return "E"
        case 2: return "B"
        case 3: return "G"
        case 4: return "D"
        case 5: return "A"
        case 6: return "E"
        default: return ""
        }
    }

    private var notePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Note", systemImage: "music.note")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MusicalNote.allCases, id: \.self) { note in
                        Button {
                            selectedNote = note
                        } label: {
                            Text(note.displayName(format: .sharps))
                                .font(DesignSystem.Typography.bodyLabel)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedNote == note ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedNote == note ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: selectedNote)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var sessionLengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Session Length", systemImage: "number.circle")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Spacer()
                Text("\(sessionLength) questions")
                    .font(DesignSystem.Typography.bodyLabel)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 20)

            GradientSlider(
                value: Binding(
                    get: { Double(sessionLength) },
                    set: { sessionLength = Int($0) }
                ),
                range: 5...100,
                step: 1
            )
            .frame(height: 36)
            .padding(.horizontal, 20)

            Text(sessionLengthHint)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.muted)
                .padding(.horizontal, 20)
        }
    }

    private var sessionLengthHint: String {
        if sessionLength <= 10 { return "Quick session — great for a warm-up" }
        if sessionLength <= 25 { return "Standard session — solid practice" }
        if sessionLength <= 50 { return "Extended session — deep focus work" }
        return "Marathon session — for the dedicated"
    }

    private var timerDurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Timer Duration", systemImage: "timer")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Spacer()
                Text("\(timerDuration)s")
                    .font(DesignSystem.Typography.bodyLabel)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 20)

            GradientSlider(
                value: Binding(
                    get: { Double(timerDuration) },
                    set: { timerDuration = Int($0) }
                ),
                range: 2...20,
                step: 1
            )
            .frame(height: 36)
            .padding(.horizontal, 20)
        }
    }

    private var noteVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Note Visibility", systemImage: "eye")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Button {
                    showPracticeModeInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(NoteVisibility.allCases, id: \.self) { vis in
                    NoteVisibilityChip(
                        visibility: vis,
                        isSelected: noteVisibility == vis
                    ) {
                        noteVisibility = vis
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var fretPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Frets", systemImage: "rectangle.grid.1x2")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Spacer()
                Button("Open") { selectedFrets = Set(0...4) }
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.cherry)
                Button("All") { selectedFrets = Set(0...12) }
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0...12, id: \.self) { fret in
                        let isSelected = selectedFrets.contains(fret)
                        Button {
                            if isSelected {
                                if selectedFrets.count > 1 {
                                    selectedFrets.remove(fret)
                                }
                            } else {
                                selectedFrets.insert(fret)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(fret == 0 ? "Open" : "\(fret)")
                                    .font(DesignSystem.Typography.bodyLabel)
                                    .monospacedDigit()
                                if fret > 0 {
                                    // Position marker dot indicator
                                    Circle()
                                        .fill(Self.isMarkerFret(fret)
                                              ? (isSelected ? DesignSystem.Colors.text.opacity(0.7) : DesignSystem.Colors.cherry.opacity(0.5))
                                              : Color.clear)
                                        .frame(width: 5, height: 5)
                                } else {
                                    Spacer().frame(height: 5)
                                }
                            }
                            .frame(width: 46)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            Text(selectedFretsSummary)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.2), value: selectedFrets)
        }
    }

    private var selectedFretsSummary: String {
        let sorted = selectedFrets.sorted()
        if sorted == Array(0...12) { return "All frets (open – 12)" }
        let labels = sorted.map { $0 == 0 ? "Open" : "Fret \($0)" }
        return labels.joined(separator: ", ")
    }

    /// Frets that have a position marker dot on a standard guitar.
    private static func isMarkerFret(_ fret: Int) -> Bool {
        [3, 5, 7, 9, 12].contains(fret)
    }

    /// String group options for chord progression constraint.
    private var chordStringGroupOptions: [(label: String, strings: [Int])] {
        [
            ("All", []),
            ("1–2–3", [1, 2, 3]),
            ("2–3–4", [2, 3, 4]),
            ("3–4–5", [3, 4, 5]),
            ("4–5–6", [4, 5, 6])
        ]
    }

    // MARK: - Chord Progression Section

    private var chordProgressionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Chord Progression", systemImage: "pianokeys")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Button {
                    showChordProgressionInfo = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .padding(.horizontal, 20)

            // Key picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Key")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MusicalNote.allCases, id: \.self) { note in
                            Button {
                                progressionKey = note
                            } label: {
                                Text(note.sharpName)
                                    .font(DesignSystem.Typography.bodyLabel)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        progressionKey == note ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(progressionKey == note ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: progressionKey)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Chord Tones picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Chord Tones")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ChordToneSelection.allCases, id: \.self) { selection in
                            Button {
                                chordToneSelection = selection
                            } label: {
                                Text(selection.label)
                                    .font(DesignSystem.Typography.bodyLabel)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        chordToneSelection == selection ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(chordToneSelection == selection ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: chordToneSelection)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Position constraint
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Position")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Spacer()
                    Toggle("", isOn: $chordPositionEnabled)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                if chordPositionEnabled {
                    fretPickerSection
                }
            }

            // String group constraint
            VStack(alignment: .leading, spacing: 6) {
                Text("String Group")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chordStringGroupOptions, id: \.label) { option in
                            let isSelected = chordStringGroup == option.strings
                            Button {
                                chordStringGroup = option.strings
                            } label: {
                                Text(option.label)
                                    .font(DesignSystem.Typography.bodyLabel)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Preset chips (2-column grid)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(Array(ChordProgression.presets.enumerated()), id: \.offset) { idx, preset in
                    Button {
                        selectedPresetIndex = idx
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(DesignSystem.Typography.smallLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(preset.transposed(toKey: progressionKey).shortDescription)
                                .font(.system(size: 9))
                                .foregroundStyle(selectedPresetIndex == idx ? .white.opacity(0.8) : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selectedPresetIndex == idx ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        )
                        .foregroundStyle(selectedPresetIndex == idx ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedPresetIndex)
                }

                // Custom option
                Button {
                    selectedPresetIndex = nil
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom")
                            .font(DesignSystem.Typography.smallLabel)
                        Text("Build your own")
                            .font(.system(size: 9))
                            .foregroundStyle(selectedPresetIndex == nil ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        selectedPresetIndex == nil ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    )
                    .foregroundStyle(selectedPresetIndex == nil ? .white : .primary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selectedPresetIndex)
            }
            .padding(.horizontal, 20)

            // Custom builder — shown only when "Custom" is selected
            if selectedPresetIndex == nil {
                customProgressionBuilder
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPresetIndex)
    }

    private var customProgressionBuilder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom Chords")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Spacer()
                // Add / remove chord buttons
                if customProgression.chords.count < 4 {
                    Button {
                        customProgression.chords.append(
                            ChordSlot(root: .c, quality: .major)
                        )
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.cherry)
                    }
                    .buttonStyle(.plain)
                }
                if customProgression.chords.count > 1 {
                    Button {
                        customProgression.chords.removeLast()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.wrong)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            ForEach($customProgression.chords) { $slot in
                HStack(spacing: 10) {
                    // Root note picker
                    Picker("Root", selection: $slot.root) {
                        ForEach(MusicalNote.allCases, id: \.self) { note in
                            Text(note.sharpName).tag(note)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.surface,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))

                    // Quality picker
                    Picker("Quality", selection: $slot.quality) {
                        ForEach(ChordQuality.allCases, id: \.self) { q in
                            Text(q.label).tag(q)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        let targetNotes: [MusicalNote] = selectedFocusMode == .singleNote ? [selectedNote] : []

        let targetStrings: [Int]
        if selectedFocusMode == .singleString || (isCircleMode && circleConstraint == .strings) {
            targetStrings = Array(selectedStrings)
        } else if selectedFocusMode == .chordProgression && !chordStringGroup.isEmpty {
            targetStrings = chordStringGroup
        } else {
            targetStrings = []
        }

        let fretStart: Int
        let fretEnd: Int
        if selectedFocusMode == .fretboardPosition
            || (isCircleMode && circleConstraint == .position)
            || (selectedFocusMode == .chordProgression && chordPositionEnabled) {
            fretStart = selectedFrets.min() ?? 0
            fretEnd = selectedFrets.max() ?? 12
        } else {
            fretStart = 0
            fretEnd = 12
        }

        // Build the chord progression to attach to the session.
        let resolvedProgression: ChordProgression? = {
            guard selectedFocusMode == .chordProgression else { return nil }
            let base: ChordProgression
            if let idx = selectedPresetIndex {
                base = ChordProgression.presets[idx]
            } else {
                base = customProgression
            }
            var transposed = base.transposed(toKey: progressionKey)
            transposed.toneSelection = chordToneSelection
            return transposed
        }()

        let isAdaptive = selectedFocusMode != .circleOfFourths &&
                         selectedFocusMode != .circleOfFifths &&
                         selectedFocusMode != .chordProgression

        let session = Session(
            focusMode: selectedFocusMode,
            gameMode: selectedGameMode,
            fretRangeStart: fretStart,
            fretRangeEnd: fretEnd,
            targetNotes: targetNotes,
            targetStrings: targetStrings,
            chordProgression: resolvedProgression,
            isAdaptive: isAdaptive
        )
        Task { @MainActor in
            try? container.sessionRepository.save(session)
            let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
            // Persist choices as new defaults so quick-start and future sessions respect them.
            settings.defaultSessionLength = sessionLength
            settings.defaultGameMode = selectedGameMode
            settings.noteVisibility = noteVisibility
            settings.defaultTimerDuration = timerDuration
            try? container.settingsRepository.saveSettings(settings)
            let vm = QuizViewModel(
                session: session,
                fretboardMap: container.fretboardMap,
                settings: settings,
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                attemptRepository: container.attemptRepository
            )
            // Post the notification — ContentView receives it, dismisses this
            // sheet (via showSetup = false), and presents the quiz window.
            NotificationCenter.default.post(name: .launchQuiz, object: vm)
        }
    }

    // MARK: - Helpers

    /// Focus modes shown in the session builder. Excludes accuracy assessment
    /// (moved to Settings) and circle modes (hidden from Shed UI per spec).
    private var displayedFocusModes: [FocusMode] {
        [.fullFretboard, .singleNote,
         .fretboardPosition, .naturalNotes,
         .singleString, .sharpsAndFlats]
    }

    private func focusModeDescription(_ mode: FocusMode) -> String {
        switch mode {
        case .singleNote:          return "All strings, one note at a time"
        case .singleString:        return "All notes across your selected strings"
        case .fullFretboard:       return "Every note across all strings"
        case .fretboardPosition:   return "All strings within your selected fret range"
        case .circleOfFourths:     return "Notes in circle-of-fourths order"
        case .circleOfFifths:      return "Notes in circle-of-fifths order"
        case .chordProgression:    return "Chord-based training"
        case .accuracyAssessment:  return "Chromatic walk of every fretboard position"
        case .naturalNotes:        return "Only natural notes (no sharps or flats)"
        case .sharpsAndFlats:      return "Only sharps and flats (no naturals)"
        }
    }

    private func focusModeIcon(_ mode: FocusMode) -> String {
        switch mode {
        case .fullFretboard:       return "rectangle.grid.3x2"
        case .fretboardPosition:   return "rectangle.grid.1x2"
        case .singleNote:          return "music.note"
        case .circleOfFifths:      return "circle.dashed"
        case .circleOfFourths:     return "circle.grid.2x1"
        case .singleString:        return "minus"
        case .chordProgression:    return "pianokeys"
        case .accuracyAssessment:  return "waveform.badge.magnifyingglass"
        case .naturalNotes:        return "textformat.abc"
        case .sharpsAndFlats:      return "number"
        }
    }
}

// MARK: - FocusModeChip

private struct FocusModeChip: View {
    let mode: FocusMode
    let isSelected: Bool
    var isPremium: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(mode.localizedLabel)
                    .font(DesignSystem.Typography.bodyLabel)
                if isPremium {
                    Image(systemName: "lock.fill")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : DesignSystem.Colors.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - PracticeModeInfoSheet

private struct PracticeModeInfoSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String, Color, String)] = [
        ("Relaxed",  "metronome",           DesignSystem.Colors.correct,
         "No time pressure. Take as long as you need to identify each note. Great for beginners or focused learning."),
        ("Timed",    "timer",               DesignSystem.Colors.amber,
         "A countdown timer runs for each question. Answer before time runs out or it counts as wrong. Good for building speed."),
        ("Streak",   "flame.fill",          DesignSystem.Colors.cherry,
         "See how many correct answers you can get in a row. One wrong answer ends your streak. Perfect for testing consistency."),
        ("Session Length", "number.circle",  DesignSystem.Colors.honey,
         "Number of questions per session. Short sessions (5–10) are great for warm-ups, longer sessions (25+) for deep practice."),
        ("Timer Duration", "timer",         DesignSystem.Colors.amber,
         "Seconds allowed per question in Timed mode. Only shown when Timed practice mode is selected."),
        ("Hidden",   "eye.slash",           DesignSystem.Colors.gold,
         "The target note position is hidden during the question and only revealed after you answer. The most challenging option — tests true recall."),
        ("Show Target", "eye",             DesignSystem.Colors.honey,
         "The target note position is shown on the fretboard during the question, so you can see where to play."),
        ("Show All",  "eye.fill",          DesignSystem.Colors.amber,
         "All octave positions of the target note are highlighted on the fretboard, helping you see the note pattern across the neck.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Configure your practice session: choose a mode, set session length, and control how notes appear on the fretboard.")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)

                    ForEach(items, id: \.0) { name, icon, color, desc in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon)
                                .font(DesignSystem.Typography.sectionHeader)
                                .foregroundStyle(color)
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(DesignSystem.Typography.bodyLabel)
                                Text(desc)
                                    .font(DesignSystem.Typography.smallLabel)
                                    .foregroundStyle(DesignSystem.Colors.text2)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Session Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ChordProgressionInfoSheet

private struct ChordProgressionInfoSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Chord Progression mode trains you to find chord tones on the fretboard by drilling through each chord in your chosen progression.")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)

                    infoBlock(
                        title: "How It Works",
                        icon: "music.note.list",
                        color: DesignSystem.Colors.cherry,
                        text: "For each chord in the progression, you'll play the selected chord tones in sequence. Once all tones are played correctly, the quiz moves to the next chord."
                    )

                    infoBlock(
                        title: "Chord Tones",
                        icon: "music.note.list",
                        color: DesignSystem.Colors.amber,
                        text: "Choose which tones to drill. \"Root Only\" finds just the root — great for beginners. \"Root + 3rd\" trains major vs minor quality. \"Root + 5th\" drills power chord shapes. \"Close Triad\" covers all three tones in a playable voicing."
                    )

                    infoBlock(
                        title: "Close Voicing",
                        icon: "hand.fingers.spread",
                        color: DesignSystem.Colors.honey,
                        text: "The 3rd and 5th are chosen near the root on the fretboard, forming a close triad — just like you'd play them in a real chord shape. This builds practical muscle memory for chord positions."
                    )

                    infoBlock(
                        title: "Key Selection",
                        icon: "key",
                        color: DesignSystem.Colors.amber,
                        text: "Pick a key to transpose the progression. For example, a I–V–vi–IV in C becomes C–G–Am–F, while in G it becomes G–D–Em–C."
                    )

                    infoBlock(
                        title: "Presets & Custom",
                        icon: "slider.horizontal.3",
                        color: DesignSystem.Colors.gold,
                        text: "Choose from common progressions like I–V–vi–IV or I–IV–V, or build your own custom progression with up to 4 chords. Each chord can be major, minor, or dominant 7th."
                    )

                    Text("Tip: Try different keys to practice the same shapes in new positions on the neck.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Chord Progression Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func infoBlock(title: String, icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyLabel)
                Text(text)
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }
}

// MARK: - FocusModeInfoSheet

private struct FocusModeInfoSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let modes: [(String, String, Color, String)] = [
        ("Full Fretboard",     "rectangle.grid.3x2",  DesignSystem.Colors.cherry,
         "The full challenge — any note on any string. Tests your overall fretboard knowledge."),
        ("Same Note",          "music.note",          DesignSystem.Colors.amber,
         "Practice finding one specific note across all strings. Great for memorizing where a note appears everywhere on the fretboard."),
        ("Fretboard Position", "slider.horizontal.3", DesignSystem.Colors.gold,
         "Narrow the quiz to a specific fret range. Ideal for learning one area of the neck at a time."),
        ("Natural Notes",      "textformat.abc",      DesignSystem.Colors.correct,
         "Only natural notes (A, B, C, D, E, F, G) — no sharps or flats. A great starting point for beginners."),
        ("String Selector",    "line.3.horizontal",   DesignSystem.Colors.honey,
         "Focus on one or more specific strings. All notes on your selected strings will be quizzed."),
        ("Sharps & Flats",     "number",              DesignSystem.Colors.cherry,
         "Only sharps and flats — the notes between the naturals. Perfect for filling in the gaps once you know the natural notes.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Focus modes determine which notes are presented during your practice session.")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)

                    ForEach(modes, id: \.0) { name, icon, color, desc in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon)
                                .font(DesignSystem.Typography.sectionHeader)
                                .foregroundStyle(color)
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(DesignSystem.Typography.bodyLabel)
                                Text(desc)
                                    .font(DesignSystem.Typography.smallLabel)
                                    .foregroundStyle(DesignSystem.Colors.text2)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Focus Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - GameModeChip

private struct GameModeChip: View {
    let mode: GameMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(mode.localizedLabel)
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - NoteVisibilityChip

private struct NoteVisibilityChip: View {
    let visibility: NoteVisibility
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(visibility.displayLabel)
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
