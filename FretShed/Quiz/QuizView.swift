// QuizView.swift
// FretShed — Presentation Layer

import SwiftUI

public struct QuizView: View {

    @State private var vm: QuizViewModel
    @State private var detector = PitchDetector()
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var hintTask: Task<Void, Never>? = nil
    @Environment(\.appContainer) private var container
    var onDone: (() -> Void)? = nil
    var onRepeat: (() -> Void)? = nil
    @State private var showEndConfirm = false
    @State private var showFretHint = false
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
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }
    private var isLeftHanded: Bool {
        FretboardOrientation(rawValue: orientationRaw) == .leftHand
    }

    // MARK: - Display Setting Helpers

    private var highlighting: NoteHighlighting {
        vm.settings.defaultNoteHighlighting
    }
    private var noteDisplayMode: NoteDisplayMode {
        vm.settings.defaultNoteDisplayMode
    }
    private var fretboardDisplay: FretboardDisplay {
        vm.settings.defaultFretboardDisplay
    }

    /// Whether to reveal all positions of the target note (after a correct or incorrect answer).
    private var revealAllPositions: Bool {
        if vm.settings.tapToAnswerEnabled && vm.phase == .active { return false }
        switch highlighting {
        case .allPositions:      return true
        case .singleThenReveal:  return vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong
        case .singlePosition:    return false
        }
    }

    /// Whether to show the orange target dot on the fretboard.
    /// Hidden during active questioning when "Reveal After" is set;
    /// hidden during active phase in Tap To Answer mode (user must find from memory);
    /// revealed on both correct and incorrect feedback so the user
    /// always sees where the note is after each attempt.
    private var showTargetDot: Bool {
        if vm.settings.tapToAnswerEnabled && vm.phase == .active { return false }
        switch highlighting {
        case .singleThenReveal:  return vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong
        case .singlePosition, .allPositions: return true
        }
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

    public init(vm: QuizViewModel,
                onDone: (() -> Void)? = nil,
                onRepeat: (() -> Void)? = nil) {
        _vm = State(initialValue: vm)
        self.onDone = onDone
        self.onRepeat = onRepeat
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Stats bar — always at the top ─────────────────────
                statsBar

                if vm.phase == .complete {
                    // ── Inline results ────────────────────────────────
                    completedContent
                } else {
                    // ── Mode indicator ────────────────────────────────
                    modeIndicator

                    // ── Timer bar (timed / tempo mode only) ──────────────────────
                    if vm.session.gameMode == .timed || vm.session.gameMode == .tempo {
                        timerBar
                    }

                    // ── Main content — stacked or side-by-side ────────────
                    if vSizeClass == .compact {
                        // Landscape iPhone: prompt+actions top, fretboard bottom (full width)
                        VStack(spacing: 0) {
                            HStack(alignment: .center, spacing: 0) {
                                compactPromptView
                                    .frame(maxWidth: .infinity)

                                actionSection
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: 320)

                                if !vm.settings.tapModeEnabled && !vm.settings.tapToAnswerEnabled {
                                    InputLevelBar(level: detector.inputLevel)
                                        .frame(width: 60)
                                        .padding(.trailing, 8)
                                }
                            }
                            .padding(.vertical, 4)

                            scaledFretboard
                                .padding(.horizontal, 8)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        // Portrait: prompt first, then fretboard below
                        promptView
                            .padding(.top, 10)

                        scaledFretboard
                            .padding(.horizontal, 8)
                            .padding(.top, 10)

                        if !vm.settings.tapModeEnabled && !vm.settings.tapToAnswerEnabled {
                            InputLevelBar(level: detector.inputLevel)
                                .padding(.top, 4)
                                .padding(.horizontal, 8)
                        }

                        actionSection
                            .padding(.top, 10)
                            .padding(.horizontal, 16)

                        Spacer(minLength: 8)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("End Session?", isPresented: $showEndConfirm) {
            Button("End & Save") { Task { await vm.endSession() } }
            Button("End & Delete", role: .destructive) { Task { await vm.discardSession() } }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Save your results or discard them entirely.")
        }
        .task {
            vm.start()
            if !vm.settings.tapModeEnabled && !vm.settings.tapToAnswerEnabled {
                detector.confidenceThreshold = vm.settings.confidenceThreshold
                detector.forceBuiltInMic = vm.settings.forceBuiltInMic
                // Apply calibration profile to pre-seed the detector
                if let profile = try? container.calibrationRepository.activeProfile() {
                    let gateTrimMultiplier = pow(10.0, profile.userGateTrimDB / 20.0)
                    detector.calibratedNoiseFloor = profile.measuredNoiseFloorRMS * gateTrimMultiplier
                    let gainTrimMultiplier = pow(10.0, profile.userGainTrimDB / 20.0)
                    detector.calibratedAGCGain = profile.measuredAGCGain * gainTrimMultiplier
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
                vm.submit(detectedNote: note)
            } else {
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(holdMs))
                    guard !Task.isCancelled else { return }
                    // Confirm the same note is still being detected after the hold window.
                    guard detector.detectedNote == note, vm.phase == .active else { return }
                    vm.submit(detectedNote: note)
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
            }
        }
    }

    private var timerBar: some View {
        let total = vm.session.gameMode == .tempo
            ? vm.tempoTimeAllowance
            : Double(vm.settings.defaultTimerDuration)
        let progress = total > 0 ? vm.timeRemaining / total : 0
        let barColor: Color = progress > 0.5 ? .green : progress > 0.25 ? .orange : .red
        return HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemGroupedBackground))
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
                    .font(.caption2)
                    .foregroundStyle(vm.isTimerMuted ? .secondary : DesignSystem.Colors.primary)
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
            Spacer(minLength: 0)
            accuracyRing
            if vm.phase == .complete {
                Button("Close") { onDone?() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: Capsule())
            } else {
                Button("End") { showEndConfirm = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var modeIndicator: some View {
        HStack(spacing: 6) {
            Label(vm.session.focusMode.localizedLabel, systemImage: "scope")
            Text("·")
            Label(vm.session.gameMode.localizedLabel, systemImage: "metronome")
            if vm.session.isAdaptive {
                Text("·")
                Label("Adaptive", systemImage: "brain")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
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
                       let q = vm.currentQuestion,
                       string != q.string || fret != q.fret {
                        wrongAnswerPosition = (string, fret)
                        let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                        vm.submit(detectedNote: wrong)
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

    private var promptView: some View {
        VStack(spacing: 2) {
            // Chord progression: show the chord name and tone role above the note.
            if vm.session.focusMode == .chordProgression,
               let chord = vm.currentChord {
                HStack(spacing: 6) {
                    Text(chord.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(vm.currentToneLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            } else {
                Text(vm.settings.tapToAnswerEnabled ? "Find this note:" : "Play this note:")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let q = vm.currentQuestion {
                Text("String \(q.string)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(promptColor)
                    .monospacedDigit()

                Text(q.note.displayName(format: noteFormat))
                    .font(.system(size: 79, weight: .black, design: .rounded))
                    .foregroundStyle(promptColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: q.note)

                if showFretHint {
                    Text("Fret \(q.fret)")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .transition(.opacity)
                } else {
                    Button {
                        withAnimation { showFretHint = true }
                    } label: {
                        Label("Show Fret", systemImage: "eye")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            } else {
                ProgressView().padding()
            }
        }
    }

    /// Compact prompt for landscape — note name, string, and fret hint in a single horizontal row.
    private var compactPromptView: some View {
        HStack(spacing: 12) {
            if vm.session.focusMode == .chordProgression,
               let chord = vm.currentChord {
                VStack(spacing: 2) {
                    Text(chord.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                    Text(vm.currentToneLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(vm.settings.tapToAnswerEnabled ? "Find:" : "Play:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let q = vm.currentQuestion {
                Text(q.note.displayName(format: noteFormat))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(promptColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: q.note)

                Text("Str \(q.string)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if showFretHint {
                    Text("Fret \(q.fret)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Button {
                        withAnimation { showFretHint = true }
                    } label: {
                        Image(systemName: "eye")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Stats

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var accuracyRing: some View {
        let pct = vm.attemptCount > 0
            ? Double(vm.correctCount) / Double(vm.attemptCount) : 0.0
        return ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(pct >= 0.8 ? Color.green : pct >= 0.6 ? .orange : .red,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(pct * 100))%")
                .font(.system(size: 9, weight: .bold))
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
                    feedbackBanner(text: correctMessage, color: .green, icon: "checkmark.circle.fill")
                        .transition(.scale.combined(with: .opacity))
                }
            case .feedbackWrong:
                feedbackBanner(text: wrongMessage, color: .red, icon: "xmark.circle.fill")
                    .transition(.scale.combined(with: .opacity))
            case .active:
                if vm.settings.tapToAnswerEnabled {
                    tapToAnswerView.transition(.opacity)
                } else if vm.settings.tapModeEnabled {
                    tapModeView.transition(.opacity)
                } else {
                    micListeningView.transition(.opacity)
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
            if vSizeClass == .compact {
                // Landscape: trophy + buttons left, stats right
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Spacer()
                        completedTrophy
                        completedMasteryBadge
                        Spacer()
                        completedButtons
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().padding(.vertical, 20)

                    VStack(spacing: 16) {
                        Spacer()
                        completedStatsGrid
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Portrait: all stacked vertically
                VStack(spacing: 0) {
                    Spacer()

                    completedTrophy
                        .padding(.horizontal, 20)

                    completedStatsGrid
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    completedMasteryBadge
                        .padding(.top, 16)

                    Spacer()

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
        let tColor: Color = completedAccuracy >= 0.9 ? .yellow
            : completedAccuracy >= 0.7 ? .orange
            : .blue
        let title: String = {
            switch vm.session.gameMode {
            case .streak:
                if vm.bestStreak >= 20 { return "Unstoppable!" }
                if vm.bestStreak >= 10 { return "On Fire!" }
                if vm.bestStreak >= 5  { return "Nice Run!" }
                return "Keep Pushing!"
            case .tempo:
                if vm.tempoTimeAllowance <= 2.5 { return "Lightning Fast!" }
                if completedAccuracy >= 0.9 { return "Outstanding!" }
                return "Great Tempo!"
            default:
                if completedAccuracy >= 0.9 { return "Outstanding!" }
                if completedAccuracy >= 0.7 { return "Great Work!" }
                if completedAccuracy >= 0.5 { return "Good Effort!" }
                return "Keep Practicing!"
            }
        }()
        let subtitle: String = {
            switch vm.session.gameMode {
            case .streak:
                return "You answered \(vm.bestStreak) in a row without a mistake."
            case .tempo:
                return String(format: "You reached a %.1f second time limit per note.", vm.tempoTimeAllowance)
            default:
                if completedAccuracy >= 0.9 { return "You're mastering the fretboard." }
                if completedAccuracy >= 0.7 { return "Your knowledge is growing steadily." }
                if completedAccuracy >= 0.5 { return "Each session builds muscle memory." }
                return "Repetition is the key to mastery."
            }
        }()

        return VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tColor)
                .symbolEffect(.bounce, value: true)
            Text(title)
                .font(DesignSystem.Typography.title)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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

    private var completedStatsGrid: some View {
        let accColor: Color = completedAccuracy >= 0.8 ? .green
            : completedAccuracy >= 0.6 ? .orange : .red

        let avgTimeLabel: String = {
            let ms = vm.averageResponseTimeMs
            guard ms > 0 else { return "—" }
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }()

        return LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            switch vm.session.gameMode {
            case .streak:
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: .orange)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: .green)
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target", color: accColor)
                CompletedStatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
            case .timed:
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target",          color: accColor)
                CompletedStatCard(label: "Avg Time",    value: avgTimeLabel,                       icon: "clock.fill",      color: .cyan)
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",              icon: "flame",           color: .orange)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",               icon: "checkmark.circle", color: .green)
            case .tempo:
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: .orange)
                CompletedStatCard(label: "Fastest",     value: String(format: "%.1fs", vm.tempoTimeAllowance),
                                                                                              icon: "bolt.fill",        color: .yellow)
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target", color: accColor)
                CompletedStatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
            default:
                CompletedStatCard(label: "Accuracy",    value: "\(Int(completedAccuracy * 100))%", icon: "target", color: accColor)
                CompletedStatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
                CompletedStatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame",            color: .orange)
                CompletedStatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: .green)
            }
        }
    }

    private var completedMasteryBadge: some View {
        let mColor: Color = {
            switch vm.session.masteryLevel {
            case .mastered:   return .green
            case .proficient: return .blue
            case .developing: return .orange
            case .beginner:   return .red
            }
        }()
        return HStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
            Text(vm.session.masteryLevel.localizedLabel)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(mColor.opacity(0.15), in: Capsule())
        .foregroundStyle(mColor)
    }

    private var completedButtons: some View {
        VStack(spacing: 10) {
            Button {
                onDone?()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.primary, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Button {
                onRepeat?()
            } label: {
                Label("Repeat Session", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Colors.success)
            .padding(.horizontal, 20)

            Label("Session saved to Progress", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DesignSystem.Colors.primary,
                                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                        vm.submit(detectedNote: wrong)
                    } label: {
                        Label("Wrong", systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DesignSystem.Colors.surface,
                                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Tap Correct if you played it right, Wrong if you didn't.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Tap To Answer helper text — shown when the user taps the fretboard to answer.
    private var tapToAnswerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(DesignSystem.Colors.primary)
                Text("Tap the fretboard where you think this note is.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surface,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
    }

    /// Live mic indicator shown while the quiz is listening.
    private var micListeningView: some View {
        VStack(spacing: 10) {
            if let error = detector.error {
                if case .microphonePermissionDenied = error {
                    micPermissionDeniedBanner
                } else {
                    audioFailureBanner
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: detector.isRunning ? "mic.fill" : "mic.slash.fill")
                        .foregroundStyle(detector.isRunning ? .green : .secondary)
                    if let note = detector.detectedNote {
                        Text("Hearing: \(note.displayName(format: noteFormat))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    } else {
                        Text(detector.isRunning ? "Listening…" : "Microphone unavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.surface,
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }

            #if DEBUG
            devButtons
            #endif
        }
    }

    private var micPermissionDeniedBanner: some View {
        VStack(spacing: 8) {
            Label("Microphone access required", systemImage: "mic.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            Text("FretShed needs the microphone to hear the notes you play.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.primary,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.red.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private var audioFailureBanner: some View {
        VStack(spacing: 8) {
            Label("Audio detection unavailable", systemImage: "speaker.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Unable to start the microphone. Try restarting the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                vm.advanceManually()
            } label: {
                Text("Skip Question")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.surface,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.orange.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private func chordCompleteBanner(chord: ChordSlot) -> some View {
        let noteNames = chord.tones.map { $0.displayName(format: noteFormat) }
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.subheadline)
                Text(chord.label).font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.green)
            Text(noteNames.joined(separator: " \u{2013} "))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { vm.advanceManually() }
    }

    private func feedbackBanner(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title)
            Text(text).font(.title2.weight(.bold))
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
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(DesignSystem.Colors.primary, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .foregroundStyle(.white)
                }

                Button {
                    let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                    vm.submit(detectedNote: wrong)
                } label: {
                    Label("Wrong", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.red)
                }
            }
        }
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
        case .feedbackCorrect: return .green
        case .feedbackWrong:   return .red
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}
