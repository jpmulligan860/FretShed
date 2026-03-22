// QuizView.swift
// FretShed — Presentation Layer

import SwiftUI

struct QuizView: View {

    @State private var vm: QuizViewModel
    @State private var detector = PitchDetector()
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var hintTask: Task<Void, Never>? = nil
    @Environment(\.appContainer) private var container
    var onDone: (() -> Void)? = nil
    var onViewProgress: (() -> Void)? = nil
    var onRepeat: (() -> Void)? = nil
    var onNextSession: (([MusicalNote]?, Session?, [NoteGroup]?) -> Void)? = nil
    var phaseBeforeQuiz: LearningPhase?
    var sessionNoteGroups: [NoteGroup]?
    @State private var showEndConfirm = false
    @State private var showFretHint = false
    @State private var insightCard: InsightCard?
    @State private var phaseContextCard: (headline: String, body: String)?
    @State private var nextSessionRec: String?
    @State private var nextSessionUsesTargetNotes: Bool = false
    @State private var nextSessionPrebuilt: Session?
    @State private var nextSessionGroups: [NoteGroup]?
    @State private var phaseAdvancementMessage: String?
    @State private var diagnosticShareURL: URL? = nil
    @State private var showDiagnosticShare = false
    @State private var storedCorrectMessage: String = "Nice!"
    @State private var wrongAnswerPosition: (string: Int, fret: Int)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSizeClass

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat
    @AppStorage(LocalUserPreferences.Key.fretboardOrientation)
    private var orientationRaw: String = LocalUserPreferences.Default.fretboardOrientation
    @AppStorage(LocalUserPreferences.Key.defaultFretCount)
    private var defaultFretCount: Int = LocalUserPreferences.Default.defaultFretCount

    private var noteFormat: NoteNameFormat {
        if vm.session.focusMode == .sharpsAndFlats { return .both }
        return NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }
    private var isLeftHanded: Bool {
        FretboardOrientation(rawValue: orientationRaw) == .leftHand
    }

    // MARK: - Display Setting Helpers

    private var revealTiming: NoteRevealTiming {
        vm.settings.defaultNoteRevealTiming
    }
    private var displayCount: NoteDisplayCount {
        vm.settings.defaultNoteDisplayCount
    }
    private var noteDisplayMode: NoteDisplayMode {
        vm.settings.defaultNoteDisplayMode
    }
    private var fretboardDisplay: FretboardDisplay {
        vm.settings.defaultFretboardDisplay
    }

    private var isFeedback: Bool {
        vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong
    }

    /// Whether to reveal all positions of the target note.
    private var revealAllPositions: Bool {
        if vm.settings.tapToAnswerEnabled && vm.phase == .active { return false }
        guard displayCount == .allPositions else { return false }
        return revealTiming == .beforePlaying || isFeedback
    }

    /// Whether to show the orange target dot on the fretboard.
    /// Hidden during active phase when "After Playing" is set;
    /// hidden during active phase in Tap To Answer mode (user must find from memory);
    /// revealed on both correct and incorrect feedback so the user
    /// always sees where the note is after each attempt.
    private var showTargetDot: Bool {
        if vm.settings.tapToAnswerEnabled && vm.phase == .active { return false }
        return revealTiming == .beforePlaying || isFeedback
    }

    /// Whether to show note name labels inside the fret dots.
    private var showNoteNames: Bool {
        if vm.settings.tapToAnswerEnabled && vm.phase == .active { return false }
        switch noteDisplayMode {
        case .showNames:     return true
        case .dotsOnly:      return false
        case .revealOnPlay:  return vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong
        case .hintOnTimeout: return false  // handled separately via hintOnTimeout logic
        }
    }

    /// The fret range to display, accounting for auto-zoom around the target fret.
    private var fretRange: ClosedRange<Int> {
        let maxFret = max(defaultFretCount, 5)
        guard fretboardDisplay == .autoZoom,
              let q = vm.currentQuestion, q.fret > 0 else {
            return 0...maxFret
        }
        let window = 4
        let low  = max(1, q.fret - window / 2)
        let high = min(maxFret, low + window)
        return low...high
    }

    init(vm: QuizViewModel,
         onDone: (() -> Void)? = nil,
         onViewProgress: (() -> Void)? = nil,
         onRepeat: (() -> Void)? = nil,
         onNextSession: (([MusicalNote]?, Session?, [NoteGroup]?) -> Void)? = nil,
         phaseBeforeQuiz: LearningPhase? = nil,
         sessionNoteGroups: [NoteGroup]? = nil) {
        _vm = State(initialValue: vm)
        self.onDone = onDone
        self.onViewProgress = onViewProgress
        self.onRepeat = onRepeat
        self.onNextSession = onNextSession
        self.phaseBeforeQuiz = phaseBeforeQuiz
        self.sessionNoteGroups = sessionNoteGroups
    }

    public var body: some View {
        ZStack(alignment: .top) {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Stats bar — always at the top ─────────────────────
                statsBar

                if vm.phase == .complete {
                    // ── Inline results ────────────────────────────────
                    completedContent
                } else {
                    // ── Mode indicator ────────────────────────────────
                    modeIndicator

                    // ── Timer bar (timed mode only) ──────────────────────
                    if vm.session.gameMode == .timed || vm.session.gameMode == .tempo {
                        timerBar
                    }

                    // ── Main content — stacked or side-by-side ────────────
                    if vSizeClass == .compact {
                        // Landscape iPhone: prompt+actions top, fretboard bottom (full width)
                        VStack(spacing: 0) {
                            if vm.isInReviewSection {
                                reviewTailBanner
                            }
                            HStack(alignment: .center, spacing: 0) {
                                compactPromptView
                                    .frame(maxWidth: .infinity)

                                compactPlayedNoteView

                                actionSection
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: 320)
                            }
                            .padding(.vertical, 4)

                            scaledFretboard
                                .padding(.horizontal, 8)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        // Portrait: prompt first, then fretboard below
                        if vm.isInReviewSection {
                            reviewTailBanner
                        }
                        promptView
                            .padding(.top, 10)

                        scaledFretboard
                            .padding(.horizontal, 8)
                            .padding(.top, 10)

                        playedNoteCard
                            .padding(.top, 8)

                        actionSection
                            .padding(.top, 10)
                            .padding(.horizontal, 16)

                        Spacer(minLength: 8)
                    }
                }
            }

            // Smart Warmup intro card overlay.
            if vm.showWarmupIntro {
                warmupIntroCard
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .alert("End Session?", isPresented: $showEndConfirm) {
            Button("End & Save") { Task { await vm.endSession() } }
            Button("End & Delete", role: .destructive) { Task { await vm.discardSession() } }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Save your progress or toss it.")
        }
        .task {
            vm.start()
            if !vm.settings.tapModeEnabled && !vm.settings.tapToAnswerEnabled {
                detector.confidenceThreshold = vm.settings.confidenceThreshold
                detector.forceBuiltInMic = vm.settings.forceBuiltInMic
                // Apply calibration profile to pre-seed the detector.
                // Pre-seed noise floor (helps gate respond immediately) and
                // input source (drives input-source-aware processing).
                // AGC is NOT pre-seeded — it starts at the default (2.0) and
                // adapts naturally, matching what calibration does. Pre-seeding
                // AGC caused level display and detection problems because the
                // calibrated value (captured after playing 6 strings) was often
                // too low for the quiz context.
                // Pre-seed BEFORE start() — these values are snapshotted into the
                // tap closure during start(), so they must be set first.
                if let profile = try? container.calibrationRepository.activeProfile() {
                    let gateTrimMultiplier = pow(10.0, profile.userGateTrimDB / 20.0)
                    detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier
                    detector.calibratedInputSource = profile.inputSource
                    vm.session.calibrationProfileID = profile.id
                }
                try? await detector.start()
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            hintTask?.cancel()
            MetroDroneEngine.shared.stopMetronome()
            Task { await detector.stop() }
        }
        .onChange(of: detector.detectedNote) { _, note in
            // Only submit when the quiz is active and we have a confident detection.
            // We require the same note to be held continuously for noteHoldDurationMs
            // before accepting it, preventing fleeting detections from firing wrong answers.
            guard vm.phase == .active, let note else {
                debounceTask?.cancel()
                debounceTask = nil
                return
            }
            let holdMs = vm.settings.noteHoldDurationMs
            if holdMs <= 0 {
                vm.submit(
                    detectedNote: note,
                    detectedFrequencyHz: detector.detectedFrequency,
                    detectedConfidence: detector.detectedConfidence,
                    centsDeviation: detector.centsDeviation
                )
            } else {
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(holdMs))
                    guard !Task.isCancelled else { return }
                    // Confirm the same note is still being detected after the hold window.
                    guard detector.detectedNote == note, vm.phase == .active else { return }
                    vm.submit(
                        detectedNote: note,
                        detectedFrequencyHz: detector.detectedFrequency,
                        detectedConfidence: detector.detectedConfidence,
                        centsDeviation: detector.centsDeviation
                    )
                }
            }
        }
        .onChange(of: vm.currentQuestion) { _, question in
            // Narrow pitch detection to the target string's frequency range.
            if let question {
                detector.expectedFrequencyRange = FretboardMap.frequencyRange(forString: question.string)
            } else {
                detector.expectedFrequencyRange = nil
            }
            showFretHint = false
            hintTask?.cancel()
            let timeout = vm.settings.hintTimeoutSeconds
            if timeout > 0 {
                hintTask = Task {
                    try? await Task.sleep(for: .seconds(timeout))
                    guard !Task.isCancelled else { return }
                    withAnimation { showFretHint = true }
                }
            }
        }
        .onChange(of: vm.phase) { _, newPhase in
            if newPhase == .feedbackCorrect {
                let s = vm.currentStreak
                if s >= 10 {
                    storedCorrectMessage = "🔥 \(s) in a row!"
                } else if s >= 5 {
                    storedCorrectMessage = "⚡️ Streak: \(s)!"
                } else {
                    storedCorrectMessage = ["Nice!", "Correct!", "Nailed it!", "Perfect!"].randomElement()!
                }
            }
            if newPhase == .active {
                wrongAnswerPosition = nil
                hintTask?.cancel()
                let timeout = vm.settings.hintTimeoutSeconds
                if timeout > 0 {
                    hintTask = Task {
                        try? await Task.sleep(for: .seconds(timeout))
                        guard !Task.isCancelled else { return }
                        withAnimation { showFretHint = true }
                    }
                }
            }
            if newPhase == .complete {
                debounceTask?.cancel()
                hintTask?.cancel()
                MetroDroneEngine.shared.stopMetronome()
                Task { await detector.stop() }
                loadInsightCard()
            }
        }
    }

    private var timerBar: some View {
        let total = Double(vm.settings.defaultTimerDuration)
        let progress = total > 0 ? vm.timeRemaining / total : 0
        let barColor: Color = progress > 0.5 ? DesignSystem.Colors.correct : progress > 0.25 ? DesignSystem.Colors.amber : DesignSystem.Colors.wrong
        return HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DesignSystem.Colors.surface2)
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.05), value: progress)
                }
            }
            .frame(height: 4)

            Button {
                vm.isTimerMuted.toggle()
            } label: {
                Image(systemName: vm.isTimerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(vm.isTimerMuted ? .secondary : DesignSystem.Colors.cherry)
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
    }

    // MARK: - Stats Bar & Prompt (shared between layouts)

    private var statsBar: some View {
        HStack(spacing: 10) {
            statPill(label: "Score", value: "\(vm.correctCount)/\(vm.attemptCount)")
            statPill(label: "Streak", value: "\(vm.currentStreak)🔥")
            if let remaining = vm.sessionTimeRemaining, remaining > 0 {
                statPill(label: "Time", value: formatTimeRemaining(remaining))
            }
            Spacer(minLength: 0)
            accuracyRing
            if vm.phase == .complete {
                Button("Close") { onDone?() }
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.surface2,
                                in: Capsule())
            } else {
                Button("End") { showEndConfirm = true }
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.wrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.surface2,
                                in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var modeIndicator: some View {
        HStack(spacing: 6) {
            if vm.session.focusMode == .accuracyAssessment {
                Label("Accuracy Assessment", systemImage: "waveform.badge.magnifyingglass")
                Text("·")
                Text("Cell \(vm.assessmentCurrentPosition)/\(vm.assessmentTotalCells)")
                    .monospacedDigit()
                Text("·")
                Text("Rep \(vm.assessmentCurrentRep)/\(vm.assessmentRepsPerCell)")
                    .monospacedDigit()
            } else {
                Label(vm.session.focusMode.localizedLabel, systemImage: "scope")
                Text("·")
                Label(vm.session.gameMode.localizedLabel, systemImage: "metronome")
                if vm.session.isAdaptive {
                    Text("·")
                    if vm.hasBaselineMastery {
                        Image(systemName: "scope")
                            .foregroundStyle(DesignSystem.Colors.amber)
                        Text("Adaptive")
                            .font(DesignSystem.Typography.dataSmall)
                            .foregroundStyle(DesignSystem.Colors.amber)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .foregroundStyle(DesignSystem.Colors.text2)
                        Text("Getting to know you")
                            .font(DesignSystem.Typography.dataSmall)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                }
            }
        }
        .font(DesignSystem.Typography.smallLabel)
        .foregroundStyle(DesignSystem.Colors.text2)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
    }

    private var scaledFretboard: some View {
        GeometryReader { geo in
            CompactFretboardView(
                targetQuestion: vm.currentQuestion,
                revealAllPositions: revealAllPositions,
                fretboardMap: container.fretboardMap,
                noteFormat: noteFormat,
                isLeftHanded: isLeftHanded,
                showNoteNames: showNoteNames,
                showTargetDot: showTargetDot,
                fretRange: fretRange,
                availableWidth: geo.size.width,
                answeredQuestions: vm.answeredChordTones,
                onFretTapped: vm.settings.tapToAnswerEnabled && vm.phase == .active ? { string, fret in
                    guard let note = container.fretboardMap.note(string: string, fret: fret) else { return }
                    if vm.settings.defaultNoteAcceptanceMode == .exactString,
                       let q = vm.currentQuestion {
                        // In Single String mode, accept any fret on the correct
                        // string that produces the same note name (e.g. A at fret 0
                        // and fret 12 are both correct). Overrides exact fret check.
                        let isCorrect: Bool
                        if vm.session.focusMode == .singleString {
                            // Single String: must be on the target string, any octave
                            isCorrect = string == q.string && note == q.note
                        } else {
                            // All other modes: any position with the same note name
                            isCorrect = note == q.note
                        }
                        if !isCorrect {
                            wrongAnswerPosition = (string, fret)
                            let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                            vm.submit(detectedNote: wrong)
                        } else {
                            vm.submit(detectedNote: note)
                        }
                    } else {
                        vm.submit(detectedNote: note)
                    }
                } : nil,
                targetDotColor: vm.phase == .feedbackWrong ? .green : .orange,
                wrongAnswerPosition: vm.phase == .feedbackWrong ? computedWrongPosition : nil
            )
        }
        // Fixed height from the string spacing (7 * 22 = 154pt), independent of width
        .frame(height: 22 * CGFloat(6 + 1))
    }

    /// Amber banner shown during the review tail section of the quiz.
    private var reviewTailBanner: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "square.3.layers.3d")
                Text("QUICK REVIEW")
                    .tracking(0.5)
            }
            .font(DesignSystem.Typography.sectionLabel)
            .foregroundStyle(Color(red: 0.078, green: 0.071, blue: 0.063)) // #141210

            Spacer()

            Text(vm.reviewStringSummary)
                .font(DesignSystem.Typography.sectionLabel)
                .foregroundStyle(Color(red: 0.239, green: 0.169, blue: 0.133)) // #3D2B22
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(DesignSystem.Colors.amber)
    }

    /// Brief intro card shown before the first warmup note.
    private var warmupIntroCard: some View {
        VStack(spacing: 12) {
            Spacer()
            VStack(spacing: 8) {
                Text("Let's warm up with a quick review.")
                    .font(DesignSystem.Typography.accentBody)
                    .foregroundStyle(DesignSystem.Colors.text)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(DesignSystem.Colors.surface2.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                vm.dismissWarmupIntro()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.2)) {
                vm.dismissWarmupIntro()
            }
        }
    }

    private var promptView: some View {
        VStack(spacing: 2) {
            // Review banner is handled separately — not in the prompt view.

            // Chord progression: show the chord name and tone role above the note.
            if vm.session.focusMode == .chordProgression,
               let chord = vm.currentChord {
                HStack(spacing: 6) {
                    Text(chord.label)
                        .font(DesignSystem.Typography.bodyLabel)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.cherry)
                    Text("·")
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text(vm.currentToneLabel)
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
                .padding(.bottom, 2)
            } else {
                Text(vm.settings.tapToAnswerEnabled ? "Find this note:" : "Play this note:")
                    .font(DesignSystem.Typography.promptLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }

            if let q = vm.currentQuestion {
                Text("String \(q.string)")
                    .font(DesignSystem.Typography.largeNumber)
                    .foregroundStyle(promptColor)
                    .monospacedDigit()

                Text(q.note.displayName(format: noteFormat))
                    .font(DesignSystem.Typography.noteDisplay)
                    .foregroundStyle(promptColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: q.note)

                if showFretHint {
                    Text("Fret \(q.fret)")
                        .font(DesignSystem.Typography.feedbackLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                        .transition(.opacity)
                } else {
                    Button {
                        withAnimation { showFretHint = true }
                    } label: {
                        Label("Show Fret", systemImage: "eye")
                            .font(DesignSystem.Typography.feedbackLabel)
                            .foregroundStyle(DesignSystem.Colors.cherry)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            } else {
                ProgressView().padding()
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var playedNoteCard: some View {
        Group {
            if let played = vm.detectedNote,
               vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong {
                let isCorrect = vm.phase == .feedbackCorrect
                let color = isCorrect ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong
                VStack(spacing: 2) {
                    Text("You Played:")
                        .font(DesignSystem.Typography.promptLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                    Text(played.displayName(format: noteFormat))
                        .font(DesignSystem.Typography.noteDisplay)
                        .foregroundStyle(color)
                    HStack(spacing: 6) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(isCorrect ? "Correct" : "Incorrect")
                            .font(DesignSystem.Typography.feedbackLabel)
                    }
                    .foregroundStyle(color)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .onTapGesture { vm.advanceManually() }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: vm.phase)
    }

    /// Compact "You Played" for landscape — sits between prompt and action section.
    private var compactPlayedNoteView: some View {
        Group {
            if let played = vm.detectedNote,
               vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong {
                let isCorrect = vm.phase == .feedbackCorrect
                let color = isCorrect ? DesignSystem.Colors.correct : DesignSystem.Colors.wrong
                HStack(spacing: 6) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Played:")
                        .font(DesignSystem.Typography.smallLabel)
                    Text(played.displayName(format: noteFormat))
                        .font(DesignSystem.Typography.subDisplay)
                }
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: vm.phase)
    }

    /// Compact prompt for landscape — note name, string, and fret hint in a single horizontal row.
    private var compactPromptView: some View {
        HStack(spacing: 12) {
            if vm.session.focusMode == .chordProgression,
               let chord = vm.currentChord {
                VStack(spacing: 2) {
                    Text(chord.label)
                        .font(DesignSystem.Typography.smallLabel)
                        .bold()
                        .foregroundStyle(DesignSystem.Colors.cherry)
                    Text(vm.currentToneLabel)
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            } else {
                Text(vm.settings.tapToAnswerEnabled ? "Find:" : "Play:")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }

            if let q = vm.currentQuestion {
                Text(q.note.displayName(format: noteFormat))
                    .font(DesignSystem.Typography.compactNote)
                    .foregroundStyle(promptColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: q.note)

                Text("Str \(q.string)")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .monospacedDigit()

                if showFretHint {
                    Text("Fret \(q.fret)")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .monospacedDigit()
                } else {
                    Button {
                        withAnimation { showFretHint = true }
                    } label: {
                        Image(systemName: "eye")
                            .font(DesignSystem.Typography.bodyLabel)
                            .foregroundStyle(DesignSystem.Colors.cherry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Stats

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(DesignSystem.Typography.sectionLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            Text(value)
                .font(DesignSystem.Typography.quizStatValue)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func formatTimeRemaining(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var accuracyRing: some View {
        let pct = vm.attemptCount > 0
            ? Double(vm.correctCount) / Double(vm.attemptCount) : 0.0
        return ZStack {
            Circle().stroke(DesignSystem.Colors.muted.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(pct >= 0.8 ? DesignSystem.Colors.correct : pct >= 0.6 ? DesignSystem.Colors.amber : DesignSystem.Colors.wrong,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(pct * 100))%")
                .font(DesignSystem.Typography.sectionLabel)
        }
        .frame(width: 32, height: 32)
        .animation(.easeInOut, value: pct)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Group {
            switch vm.phase {
            case .feedbackCorrect:
                if vm.showingChordCompleteSummary, let chord = vm.currentChord {
                    chordCompleteBanner(chord: chord)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    EmptyView()
                }
            case .feedbackWrong:
                EmptyView()
            case .active:
                VStack(spacing: 8) {
                    if vm.settings.tapToAnswerEnabled {
                        tapToAnswerView.transition(.opacity)
                    } else if vm.settings.tapModeEnabled {
                        tapModeView.transition(.opacity)
                    } else {
                        micListeningView.transition(.opacity)
                    }

                    if vm.session.focusMode == .accuracyAssessment {
                        Button {
                            vm.skipQuestion()
                        } label: {
                            Label("Skip", systemImage: "forward.fill")
                                .font(DesignSystem.Typography.bodyLabel)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DesignSystem.Colors.surface,
                                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                                .foregroundStyle(DesignSystem.Colors.text2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            default:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.25), value: vm.phase)
    }

    // MARK: - Completed Content (inline results)

    private var completedAccuracy: Double {
        guard vm.attemptCount > 0 else { return 0 }
        return Double(vm.correctCount) / Double(vm.attemptCount)
    }

    private var completedContent: some View {
        Group {
            if vm.session.focusMode == .accuracyAssessment {
                if vSizeClass == .compact {
                    assessmentCompletedLandscape
                } else {
                    assessmentCompletedContent
                }
            } else if vSizeClass == .compact {
                // Landscape: trophy + buttons left, stats right
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Spacer()
                        completedTrophy
                        Spacer()
                        completedButtons
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().padding(.vertical, 20)

                    ScrollView {
                        VStack(spacing: 16) {
                            completedStatsGrid
                            completedPhaseCards
                            completedNextUpCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Portrait: scrollable content above, Next Up + buttons pinned at bottom
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            completedTrophy
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            completedStatsGrid
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            completedPhaseCards
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 16)
                    }

                    // Next Up pinned above buttons so it's always visible
                    completedNextUpCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    completedButtons
                        .padding(.bottom, 32)
                }
            }
        }
    }

    private var completedTrophy: some View {
        let icon: String = completedAccuracy >= 0.9 ? "trophy.fill"
            : completedAccuracy >= 0.7 ? "star.fill"
            : "hand.thumbsup.fill"

        let headline = insightCard?.headline
        let body = insightCard?.body

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: true)
            }
            if let headline {
                Text(headline)
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                if let body {
                    Text(body)
                        .font(DesignSystem.Typography.accentDescription)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var completedStatsGrid: some View {
        let accColor: Color = completedAccuracy >= 0.8 ? DesignSystem.Colors.correct
            : completedAccuracy >= 0.6 ? DesignSystem.Colors.amber : DesignSystem.Colors.wrong

        let avgTimeLabel: String = {
            let ms = vm.averageResponseTimeMs
            guard ms > 0 else { return "—" }
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }()

        return LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            switch vm.session.gameMode {
            case .streak:
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: DesignSystem.Colors.amber)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: DesignSystem.Colors.correct)
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target", color: accColor)
                CompletedStatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: DesignSystem.Colors.cherry)
            case .timed:
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target",          color: accColor)
                CompletedStatCard(label: "Avg Time",    value: avgTimeLabel,                       icon: "clock.fill",      color: DesignSystem.Colors.honey)
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",              icon: "flame",           color: DesignSystem.Colors.amber)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",               icon: "checkmark.circle", color: DesignSystem.Colors.correct)
            default:
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target", color: accColor)
                CompletedStatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: DesignSystem.Colors.cherry)
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame",            color: DesignSystem.Colors.amber)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: DesignSystem.Colors.correct)
            }
        }
    }

    private func loadInsightCard() {
        let attempts = (try? container.attemptRepository.attempts(forSession: vm.session.id)) ?? []
        let engine = SessionInsightEngine()
        let allSessions = (try? container.sessionRepository.allSessions()) ?? []
        let masteryScores = (try? container.masteryRepository.allScores()) ?? []
        let baselineLevel = BaselineLevel.load() ?? .startingFresh
        insightCard = engine.insightForSummary(
            session: vm.session,
            sessionAttempts: attempts,
            allSessions: allSessions,
            masteryScores: masteryScores,
            baselineLevel: baselineLevel
        )
        loadPhaseContext()
    }

    private func loadPhaseContext() {
        let phaseManager = LearningPhaseManager()

        // Evaluate advancement with up-to-date mastery scores from the just-completed session
        if let allScores = try? container.masteryRepository.allScores() {
            phaseManager.evaluateAdvancement(using: allScores)
        }

        let currentPhase = phaseManager.currentPhase

        // Check for phase advancement
        if let before = phaseBeforeQuiz, currentPhase.rawValue > before.rawValue {
            let allSessions = (try? container.sessionRepository.allSessions()) ?? []
            phaseAdvancementMessage = PhaseInsightLibrary.advancementMessage(
                to: currentPhase,
                sessionCount: allSessions.count
            )
            // Override the trophy headline to celebrate the milestone
            // instead of showing a generic session insight that may contradict it
            insightCard = InsightCard(
                type: .tierTransition,
                headline: "\(before.displayName) phase complete!",
                body: "You've unlocked the \(currentPhase.displayName) phase.",
                isPositive: true,
                isMilestone: true
            )
        }

        // Next session recommendation — build the actual session so the button
        // launches exactly what's described (no double-evaluation drift).
        if let targetNotes = insightCard?.targetNotes, !targetNotes.isEmpty {
            // Override with a focused recommendation for close-to-level-up notes
            let format = NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
            let noteNames = targetNotes.prefix(4).map { $0.displayName(format: format) }
            let joined = noteNames.joined(separator: ", ")
            nextSessionRec = "Focus on \(joined) — a few more reps to level up"
            nextSessionUsesTargetNotes = true
        } else {
            let smartEngine = SmartPracticeEngine(
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                fretboardMap: container.fretboardMap,
                isPremium: container.entitlementManager.isPremium
            )
            if let (session, description) = try? smartEngine.nextSession() {
                nextSessionRec = description
                nextSessionPrebuilt = session
                nextSessionGroups = smartEngine.lastSessionPlan?.groups
            }
        }

        // Musical context from session note groups
        if let groups = sessionNoteGroups, let firstGroup = groups.first {
            let noteNames = firstGroup.targets.map { $0.note.sharpName }
            let sessionCount = (try? container.sessionRepository.allSessions().count) ?? 0
            let stringNumbers = Set(firstGroup.targets.map(\.string))
            let stringName: String? = stringNumbers.count == 1
                ? SmartPracticeEngine.stringName(stringNumbers.first!)
                : stringNumbers.sorted().map { SmartPracticeEngine.stringName($0) }.joined(separator: " and ")
            let frets = firstGroup.targets.map(\.fret)
            let body = PhaseInsightLibrary.musicalContextMessage(
                from: firstGroup.context,
                noteNames: noteNames,
                sessionCount: sessionCount,
                stringName: stringName,
                fretStart: frets.min(),
                fretEnd: frets.max()
            )
            phaseContextCard = (headline: firstGroup.context.description, body: body)
        }
    }

    // MARK: - Phase Context Cards

    @ViewBuilder
    private var completedPhaseCards: some View {
        // Phase advancement celebration
        if let celebration = phaseAdvancementMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(DesignSystem.Colors.honey)
                    Text("PHASE COMPLETE")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.honey)
                        .tracking(1.0)
                }
                Text(celebration)
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundStyle(DesignSystem.Colors.text)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .woodshopCard()
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Colors.honey.opacity(0.5), lineWidth: 2)
            )
        }

        // Musical context reveal
        if let context = phaseContextCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(DesignSystem.Colors.cherry)
                    Text("MUSICAL CONTEXT")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.cherry)
                        .tracking(1.0)
                }
                Text(context.headline)
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundStyle(DesignSystem.Colors.text)
                Text(context.body)
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .woodshopCard()
        }

    }

    /// Next Up card — extracted so it can be pinned outside the ScrollView in portrait.
    @ViewBuilder
    private var completedNextUpCard: some View {
        if let rec = nextSessionRec {
            Button {
                onNextSession?(nextSessionUsesTargetNotes ? insightCard?.targetNotes : nil, nextSessionPrebuilt, nextSessionGroups)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.correct)
                        Text("NEXT UP")
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.correct)
                            .tracking(1.0)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                    Text(rec)
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .woodshopCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var completedButtons: some View {
        VStack(spacing: 10) {
            Button {
                onDone?()
            } label: {
                Text("Back to The Shed")
                    .font(DesignSystem.Typography.screenTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button {
                    onViewProgress?()
                } label: {
                    Label("View Journey", systemImage: "chart.bar.fill")
                        .font(DesignSystem.Typography.bodyLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(DesignSystem.Colors.cherry)
                        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)

                Button {
                    onRepeat?()
                } label: {
                    Label("Repeat", systemImage: "arrow.counterclockwise")
                        .font(DesignSystem.Typography.bodyLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(DesignSystem.Colors.correct)
                        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
            }

            if vm.wasDiscarded {
                Label("Session deleted", systemImage: "trash")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            } else {
                Label("Session saved to Journey", systemImage: "checkmark.circle")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }

    /// Tap-mode buttons — shown instead of the mic listener when tap mode is enabled.
    private var tapModeView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if let q = vm.currentQuestion {
                    Button {
                        vm.submit(detectedNote: q.note)
                    } label: {
                        Label("Correct", systemImage: "checkmark")
                            .font(DesignSystem.Typography.bodyLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DesignSystem.Colors.cherry,
                                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                        vm.submit(detectedNote: wrong)
                    } label: {
                        Label("Wrong", systemImage: "xmark")
                            .font(DesignSystem.Typography.bodyLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DesignSystem.Colors.surface,
                                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(DesignSystem.Colors.wrong)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Tap Correct if you played it right, Wrong if you didn't.")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .multilineTextAlignment(.center)
        }
    }

    /// Tap To Answer helper text — shown when the user taps the fretboard to answer.
    private var tapToAnswerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(DesignSystem.Colors.cherry)
                Text("Tap the fretboard where you think this note is.")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surface,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
    }

    /// Live mic indicator shown while the quiz is listening.
    /// Combines status text with input level bar in a single compact row.
    private var micListeningView: some View {
        VStack(spacing: 10) {
            if let error = detector.error {
                if case .microphonePermissionDenied = error {
                    micPermissionDeniedBanner
                } else {
                    audioFailureBanner
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: detector.isRunning ? "mic.fill" : "mic.slash.fill")
                        .foregroundStyle(detector.isRunning ? DesignSystem.Colors.correct : .secondary)
                    if let note = detector.detectedNote {
                        Text("Hearing: \(note.displayName(format: noteFormat))")
                            .font(DesignSystem.Typography.bodyLabel)
                            .foregroundStyle(DesignSystem.Colors.text)
                            .contentTransition(.numericText())
                    } else {
                        Text(detector.isRunning ? "Listening…" : "Microphone unavailable")
                            .font(DesignSystem.Typography.bodyLabel)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                    Spacer()
                    InputLevelBar(level: detector.inputLevel)
                        .frame(width: 60, height: 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(DesignSystem.Colors.surface,
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }

        }
    }

    private var micPermissionDeniedBanner: some View {
        VStack(spacing: 8) {
            Label("Microphone access required", systemImage: "mic.slash.fill")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.wrong)
            Text("FretShed needs mic access to hear your guitar.")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(DesignSystem.Typography.bodyLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.cherry,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(DesignSystem.Colors.wrong.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private var audioFailureBanner: some View {
        VStack(spacing: 8) {
            Label("Audio detection unavailable", systemImage: "speaker.slash.fill")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.amber)
            Text("Couldn't start the mic. Try closing and reopening FretShed.")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
                .multilineTextAlignment(.center)
            Button {
                vm.advanceManually()
            } label: {
                Text("Skip Question")
                    .font(DesignSystem.Typography.bodyLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.surface,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(DesignSystem.Colors.amber.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private func chordCompleteBanner(chord: ChordSlot) -> some View {
        let noteNames = chord.tones.map { $0.displayName(format: noteFormat) }
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(DesignSystem.Typography.bodyLabel)
                Text(chord.label).font(DesignSystem.Typography.bodyLabel).bold()
            }
            .foregroundStyle(DesignSystem.Colors.correct)
            Text(noteNames.joined(separator: " \u{2013} "))
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.correct.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { vm.advanceManually() }
    }

    private func feedbackBanner(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(DesignSystem.Typography.sectionHeader)
            Text(text).font(DesignSystem.Typography.screenTitle)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        .onTapGesture { vm.advanceManually() }
    }

    private var devButtons: some View {
        HStack(spacing: 12) {
            if let q = vm.currentQuestion {
                Button {
                    vm.submit(detectedNote: q.note)
                } label: {
                    Label("Correct", systemImage: "checkmark")
                        .font(DesignSystem.Typography.bodyLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(DesignSystem.Colors.cherry, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .foregroundStyle(.white)
                }

                Button {
                    let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                    vm.submit(detectedNote: wrong)
                } label: {
                    Label("Wrong", systemImage: "xmark")
                        .font(DesignSystem.Typography.bodyLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(DesignSystem.Colors.surface,
                                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .foregroundStyle(DesignSystem.Colors.wrong)
                }
            }
        }
    }

    // MARK: - Assessment Completed Content

    /// Portrait layout for accuracy assessment results.
    private var assessmentCompletedContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    assessmentHeadlineCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    assessmentPerStringBreakdown
                        .padding(.horizontal, 20)

                    assessmentConsistencyCard
                        .padding(.horizontal, 20)

                    assessmentQuickStats
                        .padding(.horizontal, 20)

                    diagnosticReportButton
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }

            completedButtons
                .padding(.bottom, 32)
        }
        .sheet(isPresented: $showDiagnosticShare) {
            if let url = diagnosticShareURL {
                ShareSheet(items: [url])
            }
        }
    }

    /// Landscape layout for accuracy assessment results.
    private var assessmentCompletedLandscape: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                Spacer()
                assessmentHeadlineCard
                    .padding(.horizontal, 16)
                Spacer()
                completedButtons
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)

            Divider().padding(.vertical, 20)

            ScrollView {
                VStack(spacing: 16) {
                    assessmentPerStringBreakdown
                    assessmentConsistencyCard
                    assessmentQuickStats
                    diagnosticReportButton
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showDiagnosticShare) {
            if let url = diagnosticShareURL {
                ShareSheet(items: [url])
            }
        }
    }

    /// Big accuracy headline: percentage, icon, and correct/total subtitle.
    private var assessmentHeadlineCard: some View {
        let pct = completedAccuracy
        let pctInt = Int(pct * 100)
        let icon: String = pct >= 0.9 ? "trophy.fill"
            : pct >= 0.7 ? "target"
            : "hand.thumbsup.fill"
        let tColor: Color = pct >= 0.9 ? DesignSystem.Colors.honey
            : pct >= 0.7 ? DesignSystem.Colors.amber
            : DesignSystem.Colors.cherry

        return VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(tColor)
                .symbolEffect(.bounce, value: true)
            Text("\(pctInt)%")
                .font(DesignSystem.Typography.largeNumber)
                .foregroundStyle(DesignSystem.Colors.text)
            Text("Pitch Detection Accuracy")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            Text("\(vm.correctCount) correct / \(vm.attemptCount) attempts")
                .font(DesignSystem.Typography.dataSmall)
                .foregroundStyle(DesignSystem.Colors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [tColor.opacity(0.12), tColor.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
        )
    }

    /// Per-string accuracy bars: 6 rows with label, colored bar, and percentage.
    private var assessmentPerStringBreakdown: some View {
        let perString = vm.assessmentPerStringAccuracy
        return VStack(alignment: .leading, spacing: 10) {
            DesignSystem.Typography.capsLabel("PER-STRING ACCURACY")
                .padding(.bottom, 2)

            // Strings ordered 6 → 1 (low E at top)
            ForEach([6, 5, 4, 3, 2, 1], id: \.self) { stringNum in
                let data = perString[stringNum]
                let pct = data.map { $0.total > 0 ? Double($0.correct) / Double($0.total) : 0 } ?? 0
                let pctInt = Int(pct * 100)
                HStack(spacing: 8) {
                    Text(assessmentStringLabel(for: stringNum))
                        .font(DesignSystem.Typography.dataSmall)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .frame(width: 16, alignment: .trailing)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignSystem.Colors.surface2)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(assessmentBarColor(for: pct))
                                .frame(width: geo.size.width * pct, height: 10)
                        }
                    }
                    .frame(height: 10)

                    Text("\(pctInt)%")
                        .font(DesignSystem.Typography.dataSmall)
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .frame(width: 36, alignment: .trailing)
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    /// Consistency tiles: count of cells at each level (3/3, 2/3, 1/3, 0/3).
    private var assessmentConsistencyCard: some View {
        let buckets = vm.assessmentConsistencyBuckets
        return VStack(alignment: .leading, spacing: 10) {
            DesignSystem.Typography.capsLabel("CELL CONSISTENCY")
                .padding(.bottom, 2)

            HStack(spacing: 8) {
                assessmentConsistencyTile(count: buckets[3, default: 0], label: "3/3", color: DesignSystem.Colors.correct)
                assessmentConsistencyTile(count: buckets[2, default: 0], label: "2/3", color: DesignSystem.Colors.amber)
                assessmentConsistencyTile(count: buckets[1, default: 0], label: "1/3", color: DesignSystem.Colors.wrong)
                assessmentConsistencyTile(count: buckets[0, default: 0], label: "0/3", color: DesignSystem.Colors.muted)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    private func assessmentConsistencyTile(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(DesignSystem.Typography.dataDisplay)
                .foregroundStyle(color)
            Text(label)
                .font(DesignSystem.Typography.dataSmall)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
    }

    /// Quick stats row: Attempts + Best Streak.
    private var assessmentQuickStats: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            CompletedStatCard(label: "Attempts", value: "\(vm.attemptCount)", icon: "list.number", color: DesignSystem.Colors.cherry)
            CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥", icon: "flame.fill", color: DesignSystem.Colors.amber)
        }
    }

    /// Button to export and share a diagnostic report for the current assessment session.
    private var diagnosticReportButton: some View {
        Button {
            let manager = BackupManager(container: container)
            do {
                let url = try manager.exportDiagnosticReport(sessionID: vm.session.id)
                diagnosticShareURL = url
                showDiagnosticShare = true
            } catch {
                // Silently fail — diagnostic export is non-critical
            }
        } label: {
            Label("Send Diagnostic Report", systemImage: "arrow.up.doc")
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(DesignSystem.Colors.amber)
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Assessment Helpers

    /// Maps guitar string number to its standard label.
    private func assessmentStringLabel(for string: Int) -> String {
        switch string {
        case 6: return "E"
        case 5: return "A"
        case 4: return "D"
        case 3: return "G"
        case 2: return "B"
        case 1: return "e"
        default: return "\(string)"
        }
    }

    /// Returns a color for the accuracy bar based on percentage thresholds.
    private func assessmentBarColor(for accuracy: Double) -> Color {
        if accuracy >= 0.85 { return DesignSystem.Colors.correct }
        if accuracy >= 0.60 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    // MARK: - Helpers

    /// Computes the wrong answer position for fretboard display during wrong feedback.
    /// For tap-to-answer: uses the stored tapped position.
    /// For mic/tap-testing: finds the detected note on the target question's string.
    private var computedWrongPosition: (string: Int, fret: Int)? {
        // Tap-to-answer: we stored the exact tapped position
        if let pos = wrongAnswerPosition { return pos }
        // Mic / tap-testing: find where the detected wrong note lives on the target string
        guard let wrongNote = vm.detectedNote,
              let q = vm.currentQuestion else { return nil }
        for fret in fretRange {
            if container.fretboardMap.note(string: q.string, fret: fret) == wrongNote {
                return (q.string, fret)
            }
        }
        return nil
    }

    private var promptColor: Color {
        switch vm.phase {
        case .feedbackCorrect: return DesignSystem.Colors.correct
        case .feedbackWrong:   return DesignSystem.Colors.wrong
        default:               return .primary
        }
    }

    private var correctMessage: String { storedCorrectMessage }

    private var wrongMessage: String {
        if let d = vm.detectedNote, let q = vm.currentQuestion {
            return "\(d.displayName(format: noteFormat)) — need \(q.note.displayName(format: noteFormat))"
        }
        return "Not quite — keep going!"
    }
}

// MARK: - CompletedStatCard

private struct CompletedStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(DesignSystem.Typography.dataDisplay)
                    .foregroundStyle(DesignSystem.Colors.text)
                Text(label)
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .woodshopCard()
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
