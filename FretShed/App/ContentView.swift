// ContentView.swift
// FretShed — App Layer
//
// Root layout: a ZStack containing the TabView and an optional quiz overlay.
//
// Quiz / Results presentation strategy
// ─────────────────────────────────────
// The quiz is presented as a ZStack overlay ON TOP of the TabView.
// Results are shown INLINE within QuizView itself (no separate view swap).
//
// Why inline results?
//   On iOS 26 any newly-presented view (fullScreenCover, NavigationStack push,
//   ZStack view-swap) has unreliable touch delivery for its buttons.
//   QuizView's own buttons (Correct/Wrong, End, Show Hint) always work, so
//   the results content renders inside QuizView when vm.phase == .complete.
//
// Session Setup cover
// ───────────────────
// SessionSetupView is still presented with fullScreenCover on the TabView.
// After it dismisses, onDismiss calls launchQuiz(vm:) which sets
// activeQuizVM and lets the ZStack overlay appear.
//
// Notifications that remain
// ─────────────────────────
// .launchQuiz   — posted by PracticeHomeView (quick-launch & repeat-last cards)
// .showPracticeTab — posted by ProgressTabView's empty-state "Start Practicing"

import SwiftUI
import Combine

// MARK: - ContentView

struct ContentView: View {

    @Environment(\.appContainer) private var container
    @State private var selectedTab: Tab = .practice
    @State private var showSetup = false
    @State private var pendingQuizVM: QuizViewModel?
    @State private var activeQuizVM: QuizViewModel?
    @State private var showCalibration = false
    @State private var showCalibrationGate = false

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    // MARK: - Tab Enum

    enum Tab: String, CaseIterable {
        case practice   = "Practice"
        case progress   = "Progress"
        case tuner      = "Tuner"
        case metroDrone = "MetroDrone"
        case settings   = "Settings"

        var icon: String {
            switch self {
            case .practice:   return "guitars"
            case .progress:   return "chart.bar.fill"
            case .tuner:      return "tuningfork"
            case .metroDrone: return "metronome.fill"
            case .settings:   return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Tabs (always present) ────────────────────────────────────
            TabView(selection: $selectedTab) {
                practiceTab
                    .tabItem { Label(Tab.practice.rawValue,   systemImage: Tab.practice.icon) }
                    .tag(Tab.practice)

                progressTabView
                    .tabItem { Label(Tab.progress.rawValue,   systemImage: Tab.progress.icon) }
                    .tag(Tab.progress)

                tunerTabView
                    .tabItem { Label(Tab.tuner.rawValue,      systemImage: Tab.tuner.icon) }
                    .tag(Tab.tuner)

                MetroDroneView()
                    .tabItem { Label(Tab.metroDrone.rawValue, systemImage: Tab.metroDrone.icon) }
                    .tag(Tab.metroDrone)

                settingsStubView
                    .tabItem { Label(Tab.settings.rawValue,   systemImage: Tab.settings.icon) }
                    .tag(Tab.settings)
            }
            // Disable all TabView hit testing (including the Liquid Glass
            // tab bar's gesture recogniser) while the quiz overlay is
            // showing. Without this, the tab bar intercepts taps in the
            // bottom region of the screen on iOS 26.
            .allowsHitTesting(activeQuizVM == nil)

            // ── Quiz overlay (above tabs, covers full screen) ───────────
            if let vm = activeQuizVM {
                quizOverlay(vm: vm)
                    .zIndex(1)
            }
        }

        // ── Setup cover ────────────────────────────────────────────────
        .fullScreenCover(isPresented: $showSetup, onDismiss: {
            guard let vm = pendingQuizVM else { return }
            pendingQuizVM = nil
            launchQuiz(vm: vm)
        }) {
            SessionSetupView()
        }

        // ── Notification handlers (only what's still needed) ───────────
        .onReceive(NotificationCenter.default.publisher(for: .launchQuiz)
            .receive(on: RunLoop.main)) { note in
            guard let vm = note.object as? QuizViewModel else { return }
            if showSetup {
                pendingQuizVM = vm
                showSetup = false
            } else {
                launchQuiz(vm: vm)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPracticeTab)
            .receive(on: RunLoop.main)) { _ in
            selectedTab = .practice
        }

        // ── Calibration cover ────────────────────────────────────────
        .fullScreenCover(isPresented: $showCalibration) {
            CalibrationView()
        }

        // ── Calibration gate alert ──────────────────────────────────
        .alert("Calibrate Audio First", isPresented: $showCalibrationGate) {
            Button("Calibrate Now") { showCalibration = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Audio calibration is required before starting a quiz. This measures your environment and guitar for accurate note detection.")
        }
    }

    // MARK: - Quiz Overlay

    /// Full-screen overlay rendered above the TabView.
    /// Results are shown inline within QuizView itself — no separate view swap.
    /// All three results-screen actions are passed as direct closures so
    /// there is no NotificationCenter dispatch to fail.
    @ViewBuilder
    private func quizOverlay(vm: QuizViewModel) -> some View {
        QuizView(
            vm: vm,
            onDone: {
                activeQuizVM = nil
            },
            onRepeat: {
                // Capture the session before clearing the VM.
                let session = vm.session
                activeQuizVM = nil
                Task { @MainActor in
                    // Brief pause so the overlay disappears before the new one
                    // appears — avoids a jarring same-frame swap.
                    try? await Task.sleep(for: .milliseconds(350))
                    await launchRepeatSession(from: session)
                }
            }
        )
        // Fill the safe-area region. Interactive content (buttons) stays
        // within the safe area so iOS 26 delivers taps normally.
        // The background colour extends edge-to-edge via ignoresSafeArea
        // so the tab bar area is visually covered.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Quiz Launch

    private func launchQuiz(vm: QuizViewModel) {
        guard hasCompletedCalibration else {
            showCalibrationGate = true
            return
        }
        selectedTab = .practice
        activeQuizVM = vm
    }

    /// Re-creates a session using the same settings as `session` and launches it.
    private func launchRepeatSession(from session: Session) async {
        let targetNotes = session.notes.compactMap { MusicalNote(rawValue: $0) }
        let newSession = Session(
            focusMode: session.focusMode,
            gameMode: session.gameMode,
            fretRangeStart: session.fretRangeStart,
            fretRangeEnd: session.fretRangeEnd,
            targetNotes: targetNotes,
            targetStrings: session.targetStrings,
            chordProgression: session.chordProgression,
            isAdaptive: session.isAdaptive
        )
        try? container.sessionRepository.save(newSession)
        let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
        let vm = QuizViewModel(
            session: newSession,
            fretboardMap: container.fretboardMap,
            settings: settings,
            masteryRepository: container.masteryRepository,
            sessionRepository: container.sessionRepository,
            attemptRepository: container.attemptRepository
        )
        launchQuiz(vm: vm)
    }

    // MARK: - Tab Views

    private var practiceTab: some View {
        NavigationStack {
            PracticeHomeView(
                onStartPractice: {
                    guard hasCompletedCalibration else {
                        showCalibrationGate = true
                        return
                    }
                    showSetup = true
                },
                onOpenTuner: { selectedTab = .tuner },
                onCalibrateAudio: { showCalibration = true }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var progressTabView: some View {
        NavigationStack {
            ProgressTabView(
                vm: ProgressViewModel(
                    masteryRepository: container.masteryRepository,
                    sessionRepository: container.sessionRepository,
                    attemptRepository: container.attemptRepository
                )
            )
        }
    }

    private var tunerTabView: some View { TunerView() }
    private var settingsStubView: some View { SettingsView() }
}

// MARK: - PracticeHomeView

/// Landing page inside the Practice tab.
/// Does NOT own quiz or results presentation — posts .launchQuiz which
/// ContentView handles. This keeps all modal presentation at the top level.
struct PracticeHomeView: View {

    let onStartPractice: () -> Void
    let onOpenTuner: () -> Void
    let onCalibrateAudio: () -> Void
    @Environment(\.appContainer) private var container
    @State private var lastSession: Session?

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                doThisFirstCard
                heroCard
                quickStartGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .task {
            lastSession = try? container.sessionRepository.recentSessions(limit: 1).first
        }
    }

    @ViewBuilder
    private var doThisFirstCard: some View {
        if hasCompletedCalibration {
            // Compact "Calibrated" status line
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Audio Calibrated")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Re-calibrate") {
                    onCalibrateAudio()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        } else {
            // Full "Do This First" card with action buttons
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Do This First")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(.white)
                    Text("For the most accurate note detection:")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Tune your guitar.")
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Text("1.")
                                .font(.subheadline.weight(.bold))
                        }
                        Label {
                            Text("Calibrate audio for your environment.")
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Text("2.")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.95))

                    HStack(spacing: 12) {
                        Button {
                            onOpenTuner()
                        } label: {
                            Label("Open Tuner", systemImage: "tuningfork")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.25), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            onCalibrateAudio()
                        } label: {
                            Label("Calibrate Audio", systemImage: "waveform.badge.mic")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.25), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(20)
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, Color.purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Ready to practice?")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(.white)
                Text("Tap here, design a session and start building your fretboard knowledge.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "guitars.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.15))
                .padding(20)
        }
        .onTapGesture { onStartPractice() }
    }

    private var quickStartGrid: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color.teal, Color.cyan.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(.white)

                ViewThatFits(in: .horizontal) {
                    LazyVGrid(columns: [.init(), .init(), .init(), .init()], spacing: 12) {
                        if lastSession != nil { repeatLastCard }
                        quickStartCards
                    }
                    LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                        if lastSession != nil { repeatLastCard }
                        quickStartCards
                    }
                }
            }
            .padding(20)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.15))
                .padding(20)
        }
    }

    private var repeatLastCard: some View {
        Button(action: repeatLastSession) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.success)
                Text("Repeat Last")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var quickStartCards: some View {
        QuickModeCard(mode: .singleNote, label: "Same Note Full Fretboard", onTap: {
            quickLaunch(focusMode: .singleNote)
        })
        QuickModeCard(mode: .singleString, label: "Single String Workout", onTap: {
            quickLaunchRandomString()
        })
        QuickModeCard(mode: .fullFretboard, label: "Random Notes Full Fretboard", onTap: {
            quickLaunch(focusMode: .fullFretboard)
        })
    }

    private func quickLaunch(focusMode: FocusMode, targetStrings: [Int] = []) {
        Task { @MainActor in
            let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
            let session = Session(focusMode: focusMode, gameMode: .untimed, targetStrings: targetStrings)
            try? container.sessionRepository.save(session)
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

    private func quickLaunchRandomString() {
        let randomString = Int.random(in: 1...6)
        quickLaunch(focusMode: .singleString, targetStrings: [randomString])
    }

    private func repeatLastSession() {
        guard let prev = lastSession else { return }
        let targetNotes = prev.notes.compactMap { MusicalNote(rawValue: $0) }
        let session = Session(
            focusMode: prev.focusMode,
            gameMode: prev.gameMode,
            fretRangeStart: prev.fretRangeStart,
            fretRangeEnd: prev.fretRangeEnd,
            targetNotes: targetNotes,
            targetStrings: prev.targetStrings,
            chordProgression: prev.chordProgression,
            isAdaptive: prev.isAdaptive
        )
        // MainActor task so notification posts on main thread.
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
}

// MARK: - QuickModeCard

private struct QuickModeCard: View {
    let mode: FocusMode
    var label: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: modeIcon)
                    .font(.title2)
                    .foregroundStyle(modeColor)
                Text(label ?? mode.localizedLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var modeIcon: String {
        switch mode {
        case .fullFretboard:      return "rectangle.grid.3x2"
        case .fretboardPosition:  return "rectangle.grid.1x2"
        case .singleNote:         return "music.note"
        case .circleOfFifths:     return "circle.dashed"
        case .circleOfFourths:    return "circle.grid.2x1"
        case .singleString:       return "line.3.horizontal"
        case .chordProgression:   return "pianokeys"
        }
    }

    private var modeColor: Color {
        switch mode {
        case .fullFretboard:      return DesignSystem.Colors.primary
        case .fretboardPosition:  return DesignSystem.Colors.secondary
        case .singleNote:         return DesignSystem.Colors.info
        case .circleOfFifths:     return DesignSystem.Colors.warning
        case .singleString:       return DesignSystem.Colors.secondary
        default:                  return DesignSystem.Colors.secondary
        }
    }
}

// MARK: - StubView

struct StubView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.appContainer, AppContainer.makeForTesting())
}
