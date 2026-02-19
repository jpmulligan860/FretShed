// QuizView.swift
// FretMaster — Presentation Layer

import SwiftUI

public struct QuizView: View {

    @State private var vm: QuizViewModel
    @State private var detector = PitchDetector()
    @State private var debounceTask: Task<Void, Never>? = nil
    @Environment(\.appContainer) private var container
    @State private var showEndConfirm = false
    @State private var showFretHint = false
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

    /// Whether to reveal all positions of the target note (e.g. after a correct answer).
    private var revealAllPositions: Bool {
        switch highlighting {
        case .allPositions:      return true
        case .singleThenReveal:  return vm.phase == .feedbackCorrect
        case .singlePosition:    return false
        }
    }

    /// Whether to show note name labels inside the fret dots.
    private var showNoteNames: Bool {
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

    public init(vm: QuizViewModel) {
        _vm = State(initialValue: vm)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Stats bar — always at the top ─────────────────────
                statsBar

                // ── Mode indicator ────────────────────────────────────
                modeIndicator

                // ── Timer bar (timed / tempo mode only) ──────────────────────
                if vm.session.gameMode == .timed || vm.session.gameMode == .tempo {
                    timerBar
                }

                // ── Main content — stacked or side-by-side ────────────
                if vSizeClass == .compact {
                    // Landscape iPhone: fretboard left, prompt+actions right
                    HStack(alignment: .center, spacing: 0) {
                        scaledFretboard
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) {
                                InputLevelBar(level: detector.inputLevel)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 2)
                            }

                        Divider()

                        VStack(spacing: 12) {
                            promptView
                            actionSection
                                .padding(.horizontal, 16)
                            Spacer(minLength: 0)
                        }
                        .padding(.top, 12)
                        .frame(maxWidth: 300)
                    }
                } else {
                    // Portrait: fretboard scaled to fit screen width
                    scaledFretboard
                        .padding(.horizontal, 8)
                        .padding(.top, 10)

                    InputLevelBar(level: detector.inputLevel)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)

                    promptView
                        .padding(.top, 10)

                    actionSection
                        .padding(.top, 10)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 8)
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
            detector.confidenceThreshold = vm.settings.confidenceThreshold
            detector.forceBuiltInMic = vm.settings.forceBuiltInMic
            try? await detector.start()
        }
        .onDisappear {
            debounceTask?.cancel()
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
        .onChange(of: vm.currentQuestion) { _, _ in
            showFretHint = false
        }
        .fullScreenCover(isPresented: Binding(get: { vm.phase == .complete }, set: { _ in })) {
            SessionSummaryView(vm: vm, onDone: { dismiss() })
        }
    }

    private var timerBar: some View {
        let total = vm.session.gameMode == .tempo
            ? vm.tempoTimeAllowance
            : Double(vm.settings.defaultTimerDuration)
        let progress = total > 0 ? vm.timeRemaining / total : 0
        let barColor: Color = progress > 0.5 ? .green : progress > 0.25 ? .orange : .red
        return GeometryReader { geo in
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
    }

    // MARK: - Stats Bar & Prompt (shared between layouts)

    private var statsBar: some View {
        HStack(spacing: 10) {
            statPill(label: "Score", value: "\(vm.correctCount)/\(vm.attemptCount)")
            statPill(label: "Streak", value: "\(vm.currentStreak)🔥")
            Spacer(minLength: 0)
            accuracyRing
            Button("End") { showEndConfirm = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground),
                            in: Capsule())
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
        .background(Color(.secondarySystemGroupedBackground))
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
                fretRange: fretRange,
                availableWidth: geo.size.width
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
                        .foregroundStyle(.indigo)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(vm.currentToneLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            } else {
                Text("Play this note:")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let q = vm.currentQuestion {
                Text(q.note.displayName(format: noteFormat))
                    .font(.system(size: 79, weight: .black, design: .rounded))
                    .foregroundStyle(promptColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: q.note)

                Text("String \(q.string)")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if showFretHint {
                    Text("Fret \(q.fret)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .transition(.opacity)
                } else {
                    Button {
                        withAnimation { showFretHint = true }
                    } label: {
                        Label("Show Fret", systemImage: "eye")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            } else {
                ProgressView().padding()
            }
        }
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
                feedbackBanner(text: correctMessage, color: .green, icon: "checkmark.circle.fill")
                    .transition(.scale.combined(with: .opacity))
            case .feedbackWrong:
                feedbackBanner(text: wrongMessage, color: .red, icon: "xmark.circle.fill")
                    .transition(.scale.combined(with: .opacity))
            case .active:
                micListeningView.transition(.opacity)
            default:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.25), value: vm.phase)
    }

    /// Live mic indicator shown while the quiz is listening.
    private var micListeningView: some View {
        VStack(spacing: 10) {
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
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))

            #if DEBUG
            devButtons
            #endif
        }
    }

    private func feedbackBanner(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.subheadline)
            Text(text).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12))
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

    private var promptColor: Color {
        switch vm.phase {
        case .feedbackCorrect: return .green
        case .feedbackWrong:   return .red
        default:               return .primary
        }
    }

    private var correctMessage: String {
        let s = vm.currentStreak
        if s >= 10 { return "🔥 \(s) in a row!" }
        if s >= 5  { return "⚡️ Streak: \(s)!" }
        return ["Nice!", "Correct!", "Nailed it!", "Perfect!"].randomElement()!
    }

    private var wrongMessage: String {
        if let d = vm.detectedNote, let q = vm.currentQuestion {
            return "\(d.displayName(format: noteFormat)) — need \(q.note.displayName(format: noteFormat))"
        }
        return "Not quite — keep going!"
    }
}
