// ContentView.swift
// FretShed — App Layer
//
// Root layout: a ZStack containing the TabView and an optional quiz overlay.
// Quiz state management is delegated to QuizLaunchCoordinator.
//
// Notifications that remain
// ─────────────────────────
// .launchQuiz      — posted by PracticeHomeView (quick-launch & repeat-last cards)
// .showPracticeTab — posted by ProgressTabView's empty-state "Start Practicing"

import SwiftUI
import Combine

// MARK: - ContentView

struct ContentView: View {

    @Environment(\.appContainer) private var container
    @State private var quiz = QuizLaunchCoordinator()
    @State private var progressVM: ProgressViewModel?

    // MARK: - Body

    var body: some View {
        @Bindable var quiz = quiz
        ZStack {
            // ── Tabs (always present) ────────────────────────────────────
            TabView(selection: $quiz.selectedTab) {
                practiceTab
                    .tabItem { Label(AppTab.practice.rawValue,   systemImage: AppTab.practice.icon) }
                    .tag(AppTab.practice)

                progressTabView
                    .tabItem { Label(AppTab.progress.rawValue,   systemImage: AppTab.progress.icon) }
                    .tag(AppTab.progress)

                tunerTabView
                    .tabItem { Label(AppTab.tuner.rawValue,      systemImage: AppTab.tuner.icon) }
                    .tag(AppTab.tuner)

                MetroDroneView()
                    .tabItem { Label(AppTab.metroDrone.rawValue, systemImage: AppTab.metroDrone.icon) }
                    .tag(AppTab.metroDrone)

                settingsStubView
                    .tabItem { Label(AppTab.settings.rawValue,   systemImage: AppTab.settings.icon) }
                    .tag(AppTab.settings)
            }
            .tint(DesignSystem.Colors.cherry)
            // Disable all TabView hit testing (including the Liquid Glass
            // tab bar's gesture recogniser) while the quiz overlay is
            // showing. Without this, the tab bar intercepts taps in the
            // bottom region of the screen on iOS 26.
            .allowsHitTesting(quiz.activeQuizVM == nil)

            // ── Quiz overlay (above tabs, covers full screen) ───────────
            if let vm = quiz.activeQuizVM {
                quizOverlay(vm: vm)
                    .zIndex(1)
            }
        }

        // ── Setup cover ────────────────────────────────────────────────
        .fullScreenCover(isPresented: $quiz.showSetup, onDismiss: {
            quiz.handleSetupDismiss()
        }) {
            SessionSetupView()
        }

        // ── Notification handlers (only what's still needed) ───────────
        .onReceive(NotificationCenter.default.publisher(for: .launchQuiz)
            .receive(on: RunLoop.main)) { note in
            guard let vm = note.object as? QuizViewModel else { return }
            quiz.handleLaunchNotification(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPracticeTab)
            .receive(on: RunLoop.main)) { _ in
            quiz.selectedTab = .practice
        }

        // ── Calibration cover (re-calibrate from compact card / Settings) ──
        .fullScreenCover(isPresented: $quiz.showCalibration) {
            CalibrationView()
        }

        // ── Calibration tuner cover (audio setup flow from Do This First) ──
        .fullScreenCover(isPresented: $quiz.showCalibrationTuner, onDismiss: {
            quiz.handleCalibrationTunerDismiss()
        }) {
            CalibrationTunerView()
        }

        // ── Calibration gate alert ──────────────────────────────────
        .alert("Audio Setup Required", isPresented: $quiz.showCalibrationGate) {
            Button("Calibrate Now") { quiz.handleCalibrateNow() }
            Button("Use Tap Mode") { quiz.handleUseTapModeFromGate() }
            Button("Cancel", role: .cancel) { quiz.handleCancelGate() }
        } message: {
            Text("Audio calibration is required for note detection. You can calibrate now or use tap mode to practice without audio.")
        }

        .task {
            quiz.container = container
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
            onDone: { quiz.handleQuizDone(vm: vm) },
            onRepeat: { quiz.handleQuizRepeat(vm: vm) }
        )
        // Fill the safe-area region. Interactive content (buttons) stays
        // within the safe area so iOS 26 delivers taps normally.
        // The background colour extends edge-to-edge via ignoresSafeArea
        // so the tab bar area is visually covered.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    // MARK: - Tab Views

    private var practiceTab: some View {
        NavigationStack {
            PracticeHomeView(
                onStartPractice: { quiz.handleStartPractice() },
                onSetupAudio: { quiz.handleSetupAudio() },
                onUseTapMode: { quiz.handleUseTapModeFromHome() },
                onCalibrateAudio: { quiz.handleCalibrateAudio() }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var progressTabView: some View {
        NavigationStack {
            if let vm = progressVM {
                ProgressTabView(vm: vm)
            }
        }
        .task {
            if progressVM == nil {
                progressVM = ProgressViewModel(
                    masteryRepository: container.masteryRepository,
                    sessionRepository: container.sessionRepository,
                    attemptRepository: container.attemptRepository
                )
            }
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
    let onSetupAudio: () -> Void
    let onUseTapMode: () -> Void
    let onCalibrateAudio: () -> Void
    @Environment(\.appContainer) private var container
    @State private var lastSession: Session?

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Shed")
                        .font(DesignSystem.Typography.screenTitle)
                        .foregroundStyle(DesignSystem.Colors.text)
                    Text("Time to put in the work.")
                        .font(DesignSystem.Typography.tagline)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                doThisFirstCard
                heroCard
                quickStartGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(DesignSystem.Colors.background)
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
                    .foregroundStyle(DesignSystem.Colors.correct)
                Text("Audio Calibrated")
                    .font(DesignSystem.Typography.bodyLabel)
                Spacer()
                Button("Re-calibrate") {
                    onCalibrateAudio()
                }
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.cherry)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        } else {
            // Full "Do This First" card — two paths: audio detection or tap mode
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(DesignSystem.Gradients.primary)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Do This First")
                        .font(DesignSystem.Typography.screenTitle)
                        .foregroundStyle(.white)
                    Text("Choose how you want to practice:")
                        .font(DesignSystem.Typography.accentDescription)
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 12) {
                        Button {
                            onSetupAudio()
                        } label: {
                            Label("Use Audio Detection", systemImage: "mic.fill")
                                .font(DesignSystem.Typography.bodyLabel)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.25), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            onUseTapMode()
                        } label: {
                            Label("Use Tap Mode", systemImage: "hand.tap")
                                .font(DesignSystem.Typography.bodyLabel)
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
                        colors: [DesignSystem.Colors.cherry, DesignSystem.Colors.amber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Ready to practice?")
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(.white)
                Text("Tap here, design a session and start building your fretboard knowledge.")
                    .font(DesignSystem.Typography.accentDescription)
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
                        colors: [DesignSystem.Colors.amber, DesignSystem.Colors.honey],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                DesignSystem.Typography.capsLabel("QUICK START")
                    .foregroundStyle(.white.opacity(0.8))

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
                    .foregroundStyle(DesignSystem.Colors.correct)
                Text("Repeat Last")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(14)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
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
                    .foregroundStyle(DesignSystem.Colors.cherry)
                Text(label ?? mode.localizedLabel)
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(14)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
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
                .foregroundStyle(DesignSystem.Colors.muted.opacity(0.5))
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(DesignSystem.Colors.text2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.muted)
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
