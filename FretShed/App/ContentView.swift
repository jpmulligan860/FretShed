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

        // ── Setup sheet (half-sheet) ──────────────────────────────────
        .sheet(isPresented: $quiz.showSetup, onDismiss: {
            quiz.handleSetupDismiss()
        }) {
            SessionSetupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            onViewProgress: { quiz.handleViewProgress(vm: vm) },
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
            PracticeHomeView(coordinator: quiz)
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

/// Landing page inside the Practice (Shed) tab.
/// Uses QuizLaunchCoordinator to launch sessions — no NotificationCenter for launches.
struct PracticeHomeView: View {

    let coordinator: QuizLaunchCoordinator
    @Environment(\.appContainer) private var container
    @State private var lastSession: Session?
    @State private var sessionCount: Int = 0
    @State private var smartEngine: SmartPracticeEngine?
    @State private var smartDescription: String = ""
    @State private var weakSpots: Int = 0
    @State private var selectedTimedMinutes: Int = 5
    @State private var timedGameMode: GameMode = .untimed
    @State private var calibrationBannerDismissed = false

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    private var isNewUser: Bool { sessionCount == 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                calibrationBanner
                primaryCTA
                if !isNewUser { compactHeatmap }
                quickStartSection
                timedPracticeSection
                buildCustomButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(DesignSystem.Colors.background)
        .task { await loadData() }
        .onAppear { refreshData() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The Shed")
                .font(DesignSystem.Typography.screenTitle)
                .foregroundStyle(DesignSystem.Colors.text)
            Text(isNewUser ? "Time to put in the work." : "Pick up where you left off.")
                .font(DesignSystem.Typography.tagline)
                .foregroundStyle(DesignSystem.Colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Calibration Banner

    @ViewBuilder
    private var calibrationBanner: some View {
        if !hasCompletedCalibration && !calibrationBannerDismissed {
            HStack(spacing: 10) {
                Image(systemName: "mic.badge.xmark")
                    .foregroundStyle(DesignSystem.Colors.amber)
                Text("Audio calibration needed")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                Spacer()
                Button("Set Up") {
                    coordinator.handleSetupAudio()
                }
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.cherry)
                Button {
                    calibrationBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
        }
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        Button {
            launchSmartPractice()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                DesignSystem.Typography.capsLabel(isNewUser ? "START HERE" : "BASED ON YOUR PROGRESS")
                    .foregroundStyle(.white.opacity(0.7))
                Text(isNewUser ? "Start Practice" : "Smart Practice")
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(.white)
                Text(isNewUser
                     ? "Adaptive session based on your level"
                     : "Next: \(smartDescription) \u{2022} \(weakSpots) weak spots")
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Heatmap

    private var compactHeatmap: some View {
        CompactHeatmapView(
            masteryRepository: container.masteryRepository,
            fretboardMap: container.fretboardMap
        )
    }

    // MARK: - Quick Start Presets

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DesignSystem.Typography.capsLabel("QUICK START")

            if isNewUser {
                HStack(spacing: 10) {
                    presetCard(icon: "play.circle.fill", title: "Guided Start", subtitle: "10 questions, relaxed") {
                        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, fretRangeEnd: 7, isAdaptive: true)
                        coordinator.launchSession(session)
                    }
                    presetCard(icon: "music.note", title: "Root Notes", subtitle: "20 questions, open position") {
                        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, fretRangeEnd: 7, isAdaptive: true)
                        coordinator.launchSession(session)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    presetCard(icon: "target", title: "Weak Spots", subtitle: "Target lowest scores") {
                        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, fretRangeEnd: 7, isAdaptive: true)
                        coordinator.launchSession(session)
                    }
                    presetCard(icon: "square.grid.3x3.topleft.filled", title: "Fill the Gaps", subtitle: "Unattempted cells") {
                        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, fretRangeEnd: 7, isAdaptive: true)
                        coordinator.launchSession(session)
                    }
                    if let prev = lastSession {
                        presetCard(
                            icon: "arrow.counterclockwise",
                            title: "Repeat Last",
                            subtitle: "\(prev.focusMode.localizedLabel) \u{2022} \(Int(prev.accuracyPercent))%"
                        ) {
                            Task { await coordinator.launchRepeatSession(from: prev) }
                        }
                    }
                }
            }
        }
    }

    private func presetCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.cherry)
                Text(title)
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(12)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timed Practice

    private var timedPracticeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(DesignSystem.Colors.cherry)
                Text("Timed Practice")
                    .font(DesignSystem.Typography.sectionHeader)
            }

            // Time chips
            HStack(spacing: 8) {
                ForEach([2, 5, 10, 15], id: \.self) { mins in
                    Button {
                        selectedTimedMinutes = mins
                    } label: {
                        Text("\(mins) min")
                            .font(DesignSystem.Typography.smallLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimedMinutes == mins ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                in: Capsule()
                            )
                            .foregroundStyle(selectedTimedMinutes == mins ? .white : DesignSystem.Colors.text)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Mode picker
            HStack(spacing: 8) {
                ForEach([GameMode.untimed, .timed, .streak], id: \.self) { mode in
                    Button {
                        timedGameMode = mode
                    } label: {
                        Text(mode.localizedLabel)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                timedGameMode == mode ? DesignSystem.Colors.surface2 : Color.clear,
                                in: Capsule()
                            )
                            .foregroundStyle(timedGameMode == mode ? DesignSystem.Colors.text : DesignSystem.Colors.muted)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Go button
            Button {
                let session = Session(
                    focusMode: .fullFretboard,
                    gameMode: timedGameMode,
                    fretRangeEnd: 7,
                    isAdaptive: true,
                    sessionTimeLimitSeconds: selectedTimedMinutes * 60
                )
                coordinator.launchSession(session)
            } label: {
                Text("Go — \(selectedTimedMinutes) Minutes")
                    .font(DesignSystem.Typography.bodyLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Build Custom

    private var buildCustomButton: some View {
        Button {
            coordinator.handleBuildCustomSession()
        } label: {
            Label("Build Custom Session", systemImage: "gear")
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(DesignSystem.Colors.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Lightweight: just check if sessions exist + get last session
        let recent = (try? container.sessionRepository.recentSessions(limit: 1)) ?? []
        lastSession = recent.first
        sessionCount = recent.isEmpty ? 0 : 1 // Only need to know new vs returning

        let engine = SmartPracticeEngine(
            masteryRepository: container.masteryRepository,
            sessionRepository: container.sessionRepository,
            fretboardMap: container.fretboardMap
        )
        smartEngine = engine
        smartDescription = engine.nextModeDescription()

        // Yield before heavier mastery query
        await Task.yield()
        weakSpots = (try? engine.weakSpotCount()) ?? 0
    }

    private func refreshData() {
        Task {
            let recent = (try? container.sessionRepository.recentSessions(limit: 1)) ?? []
            lastSession = recent.first
            sessionCount = recent.isEmpty ? 0 : 1
            if let engine = smartEngine {
                smartDescription = engine.nextModeDescription()
                weakSpots = (try? engine.weakSpotCount()) ?? 0
            }
        }
    }

    private func launchSmartPractice() {
        guard let engine = smartEngine else { return }
        guard let (session, _) = try? engine.nextSession() else { return }
        coordinator.launchSession(session)
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
