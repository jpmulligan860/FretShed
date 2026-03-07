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

    @State private var metroDroneView = MetroDroneView()
    @State private var tunerView = TunerView()
    @State private var settingsView = SettingsView()

    var body: some View {
        @Bindable var quiz = quiz
        ZStack {
            // ── All tabs always rendered, only selected is visible ────────
            VStack(spacing: 0) {
                ZStack {
                    practiceTab
                        .opacity(quiz.selectedTab == .practice ? 1 : 0)
                        .allowsHitTesting(quiz.selectedTab == .practice)

                    progressTabView
                        .opacity(quiz.selectedTab == .progress ? 1 : 0)
                        .allowsHitTesting(quiz.selectedTab == .progress)

                    tunerView
                        .opacity(quiz.selectedTab == .tuner ? 1 : 0)
                        .allowsHitTesting(quiz.selectedTab == .tuner)

                    metroDroneView
                        .opacity(quiz.selectedTab == .metroDrone ? 1 : 0)
                        .allowsHitTesting(quiz.selectedTab == .metroDrone)

                    settingsView
                        .opacity(quiz.selectedTab == .settings ? 1 : 0)
                        .allowsHitTesting(quiz.selectedTab == .settings)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if quiz.activeQuizVM == nil {
                    glassTabBar
                }
            }
            .ignoresSafeArea(.keyboard)

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
                .presentationDetents([.large])
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

        // ── Calibration cover (all calibration entry points) ──
        .fullScreenCover(isPresented: $quiz.showCalibration, onDismiss: {
            quiz.handleCalibrationDismiss()
        }) {
            CalibrationView()
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
            if progressVM == nil {
                progressVM = ProgressViewModel(
                    masteryRepository: container.masteryRepository,
                    sessionRepository: container.sessionRepository,
                    attemptRepository: container.attemptRepository
                )
            }
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
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Glass Tab Bar

    private var glassTabBar: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        quiz.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 28))
                            .symbolRenderingMode(.monochrome)
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(quiz.selectedTab == tab
                                     ? DesignSystem.Colors.cherry
                                     : DesignSystem.Colors.muted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(DesignSystem.Colors.background)
    }

}

// MARK: - PracticeHomeView

/// Landing page inside the Practice (Shed) tab.
/// Uses QuizLaunchCoordinator to launch sessions — no NotificationCenter for launches.
struct PracticeHomeView: View {

    let coordinator: QuizLaunchCoordinator
    @Environment(\.appContainer) private var container
    @State private var sessionCount: Int = 0
    @State private var smartEngine: SmartPracticeEngine?
    @State private var smartDescription: String = ""
    @State private var weakSpots: Int = 0
    @State private var alternativeTiles: [(session: Session, title: String, subtitle: String, icon: String)] = []
    @State private var showTimedPicker = false
    @State private var selectedTimedMinutes: Int = 5
    @State private var calibrationBannerDismissed = false
    @State private var activeProfileName: String?

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    private var isNewUser: Bool { sessionCount == 0 && coordinator.lastCompletedSession == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                calibrationBanner
                primaryCTA
                customSessionCTA
                quickStartSection
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
        .onChange(of: coordinator.lastCompletedSession?.id) {
            // Quiz just finished — refresh smart practice data
            if let engine = smartEngine {
                smartDescription = engine.nextModeDescription()
                weakSpots = (try? engine.weakSpotCount()) ?? 0
                alternativeTiles = (try? engine.alternativeSessions()) ?? []
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The Shed")
                .font(DesignSystem.Typography.screenTitle)
                .foregroundStyle(DesignSystem.Colors.text)
            Text(isNewUser ? "Welcome to the Woodshed, let's get to work." : "Welcome back to the Shed.")
                .font(.custom("CrimsonPro-Italic", size: 19.5))
                .foregroundStyle(DesignSystem.Colors.muted)

            if hasCompletedCalibration, let name = activeProfileName {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.correct)
                    Text("Using: \(name)")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
                .padding(.top, 2)
            }
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
                Text(isNewUser ? "Start Practice" : "Smart Practice")
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(.white)
                Text((isNewUser ? "START HERE" : "RECOMMENDED BASED ON YOUR PROGRESS").uppercased())
                    .font(DesignSystem.Typography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(.white)
                Text(isNewUser
                     ? "Adaptive session based on your level"
                     : "Next Up: \(smartDescription) \u{2022} \(weakSpots) weak spots")
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                // Row 1: two alternative modes (different from Smart Practice)
                HStack(spacing: 10) {
                    ForEach(Array(alternativeTiles.prefix(2).enumerated()), id: \.offset) { _, tile in
                        presetCard(icon: tile.icon, title: tile.title, subtitle: tile.subtitle) {
                            coordinator.launchSession(tile.session)
                        }
                    }
                }

                // Row 2: Got Time? + Repeat Last
                HStack(spacing: 10) {
                    presetCard(icon: "timer", title: "Got Time?", subtitle: "2, 5, or 10 min") {
                        showTimedPicker = true
                    }
                    if let prev = coordinator.lastCompletedSession {
                        presetCard(
                            icon: "arrow.counterclockwise",
                            title: "Repeat Last",
                            subtitle: repeatLastSubtitle(for: prev)
                        ) {
                            Task { await coordinator.launchRepeatSession(from: prev) }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTimedPicker) {
            timedPickerSheet
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
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
                    .lineLimit(2)
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

    // MARK: - Timed Picker Sheet

    private var timedPickerSheet: some View {
        VStack(spacing: 16) {
            Text("How long?")
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundStyle(DesignSystem.Colors.text)

            HStack(spacing: 12) {
                ForEach([2, 5, 10], id: \.self) { mins in
                    Button {
                        selectedTimedMinutes = mins
                    } label: {
                        Text("\(mins) min")
                            .font(DesignSystem.Typography.bodyLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedTimedMinutes == mins ? DesignSystem.Colors.cherry : DesignSystem.Colors.surface2,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(selectedTimedMinutes == mins ? .white : DesignSystem.Colors.text)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showTimedPicker = false
                let session = Session(
                    focusMode: .fullFretboard,
                    gameMode: .untimed,
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
        .padding(20)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Build Custom

    private var customSessionCTA: some View {
        Button {
            coordinator.handleBuildCustomSession()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Let Me Pick")
                    .font(DesignSystem.Typography.screenTitle)
                    .foregroundStyle(.white)
                Text("CHOOSE MY OWN PRACTICE SESSION")
                    .font(DesignSystem.Typography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(.white)
                Text("Tap to design your session")
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func repeatLastSubtitle(for session: Session) -> String {
        let mode = session.focusMode.localizedLabel
        if session.sessionTimeLimitSeconds > 0 {
            return "\(mode) \u{2022} \(session.gameMode.localizedLabel) \u{2022} \(session.sessionTimeLimitSeconds / 60) min"
        }
        return "\(mode) \u{2022} \(session.gameMode.localizedLabel)"
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Seed last completed session from DB if coordinator doesn't have one yet
        if coordinator.lastCompletedSession == nil {
            let recent = (try? container.sessionRepository.recentSessions(limit: 1)) ?? []
            if let first = recent.first {
                coordinator.lastCompletedSession = first
            }
            sessionCount = recent.isEmpty ? 0 : 1
        } else {
            sessionCount = 1
        }

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
        alternativeTiles = (try? engine.alternativeSessions()) ?? []
    }

    private func loadActiveProfileName() {
        if let profile = try? container.calibrationRepository.activeProfile() {
            activeProfileName = profile.name ?? profile.guitarType?.displayName ?? "Calibrated"
        } else {
            activeProfileName = nil
        }
    }

    private func refreshData() {
        loadActiveProfileName()
        // Session count: if coordinator has a last session, we're a returning user
        if coordinator.lastCompletedSession != nil {
            sessionCount = 1
        } else {
            let recent = (try? container.sessionRepository.recentSessions(limit: 1)) ?? []
            if let first = recent.first {
                coordinator.lastCompletedSession = first
            }
            sessionCount = recent.isEmpty ? 0 : 1
        }
        if let engine = smartEngine {
            smartDescription = engine.nextModeDescription()
            weakSpots = (try? engine.weakSpotCount()) ?? 0
            alternativeTiles = (try? engine.alternativeSessions()) ?? []
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
