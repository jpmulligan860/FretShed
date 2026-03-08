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
            CalibrationView(forceNewProfile: quiz.calibrationForceNewProfile)
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
        .onChange(of: quiz.needsProgressReload) { _, needsReload in
            guard needsReload else { return }
            quiz.needsProgressReload = false
            Task { await progressVM?.load() }
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
            PracticeHomeView(
                coordinator: quiz,
                currentStreak: progressVM?.currentStreak ?? 0,
                totalTimePracticed: progressVM?.recentSessions.reduce(0.0) { $0 + $1.duration } ?? 0
            )
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
                            .font(DesignSystem.Typography.smallLabel)
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
    var currentStreak: Int = 0
    var totalTimePracticed: TimeInterval = 0
    @Environment(\.appContainer) private var container
    @State private var sessionCount: Int = 0
    @State private var smartEngine: SmartPracticeEngine?
    @State private var smartDescription: String = ""
    @State private var weakSpots: Int = 0
    @State private var alternativeTiles: [(session: Session, title: String, subtitle: String, icon: String)] = []
    @State private var showTimedPicker = false
    @State private var selectedTimedMinutes: Int = 5
    @State private var allProfiles: [AudioCalibrationProfile] = []
    @State private var rigPickerExpanded = false
    @State private var showTimeStat = false

    @AppStorage(LocalUserPreferences.Key.hasCompletedCalibration)
    private var hasCompletedCalibration = false

    private var isNewUser: Bool { sessionCount == 0 && coordinator.lastCompletedSession == nil }

    private var formattedTimePracticed: String {
        let total = Int(totalTimePracticed)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        if mins > 0 { return "\(mins)m" }
        return "\(total)s"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                rigProfileCard
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
        .onChange(of: coordinator.showCalibration) { _, showing in
            if !showing { refreshData() }
        }
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
            if !isNewUser {
                Group {
                    if !showTimeStat && currentStreak > 0 {
                        HStack(spacing: 4) {
                            Text("You've got a")
                            Image(systemName: "flame.fill")
                                .foregroundStyle(DesignSystem.Colors.amber)
                            Text("\(currentStreak) day streak")
                                .fontWeight(.semibold)
                            Text("going!")
                        }
                    } else if totalTimePracticed > 0 {
                        HStack(spacing: 4) {
                            Text("Wow! You've spent")
                            Text(formattedTimePracticed)
                                .fontWeight(.semibold)
                            Text("in the Shed!")
                        }
                    }
                }
                .font(.custom("CrimsonPro-Italic", size: 19.5))
                .foregroundStyle(DesignSystem.Colors.muted)
                .animation(.easeInOut(duration: 0.4), value: showTimeStat)
                .onAppear {
                    showTimeStat = Bool.random()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rig Profile Card

    private var rigProfileCard: some View {
        let activeProfile = allProfiles.first(where: \.isActive)

        return Group {
            if activeProfile == nil {
                // Pre-calibration state
                Button {
                    coordinator.handleSetupAudio()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.amber.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "guitars.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.amber)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Calibrate My Guitar First")
                                .font(DesignSystem.Typography.bodyLabel)
                                .foregroundStyle(DesignSystem.Colors.text)
                            Text("FretShed is most accurate when you profile your rig.")
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(DesignSystem.Colors.muted)
                            Text("Tap here and follow the instructions")
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(DesignSystem.Colors.cherry)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.muted)
                    }
                    .padding(14)
                    .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Post-calibration: show active profile with inline picker
                VStack(spacing: 0) {
                    // Header row
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rigPickerExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.cherry.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: activeProfile?.guitarType?.iconName ?? "guitars.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(DesignSystem.Colors.cherry)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("My Rig")
                                    .font(DesignSystem.Typography.smallLabel)
                                    .foregroundStyle(DesignSystem.Colors.muted)
                                HStack(spacing: 6) {
                                    Text(activeProfile?.displayName ?? "Guitar")
                                        .font(DesignSystem.Typography.bodyLabel)
                                        .foregroundStyle(DesignSystem.Colors.text)
                                    Image(systemName: rigPickerExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(DesignSystem.Colors.muted)
                                }
                                Text("Tap to add a new guitar rig or change guitars.")
                                    .font(DesignSystem.Typography.smallLabel)
                                    .foregroundStyle(DesignSystem.Colors.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.correct)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(14)

                    // Expandable profile list
                    if rigPickerExpanded {
                        Divider()
                            .overlay(DesignSystem.Colors.border)
                            .padding(.horizontal, 14)

                        VStack(spacing: 0) {
                            ForEach(allProfiles, id: \.id) { profile in
                                Button {
                                    setActiveProfile(profile)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        rigPickerExpanded = false
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                                            .font(.body)
                                            .foregroundStyle(profile.isActive ? DesignSystem.Colors.cherry : DesignSystem.Colors.muted)
                                        Text(profile.displayName)
                                            .font(DesignSystem.Typography.bodyLabel)
                                            .foregroundStyle(DesignSystem.Colors.text)
                                        if let type = profile.guitarType {
                                            Text(type.displayName)
                                                .font(DesignSystem.Typography.smallLabel)
                                                .foregroundStyle(DesignSystem.Colors.text2)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }

                            Divider()
                                .overlay(DesignSystem.Colors.border)
                                .padding(.horizontal, 14)

                            Button {
                                rigPickerExpanded = false
                                coordinator.handleCreateNewProfile()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle")
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.Colors.cherry)
                                    Text("Create New Rig Profile")
                                        .font(DesignSystem.Typography.bodyLabel)
                                        .foregroundStyle(DesignSystem.Colors.cherry)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
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
                Text((isNewUser ? "START HERE" : "BASED ON YOUR PROGRESS").uppercased())
                    .font(DesignSystem.Typography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(.white)
                Text(isNewUser
                     ? "Adaptive session based on your level"
                     : "Tap for Suggested Session: \(smartDescription) \u{2022} \(weakSpots) weak spots")
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.cherry)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
                Text("DESIGN A CUSTOM SESSION")
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

    private func loadProfiles() {
        allProfiles = (try? container.calibrationRepository.allProfiles()) ?? []
    }

    private func setActiveProfile(_ profile: AudioCalibrationProfile) {
        try? container.calibrationRepository.setActive(profile)
        loadProfiles()
    }

    private func refreshData() {
        loadProfiles()
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
                .font(DesignSystem.Typography.screenTitle)
                .foregroundStyle(DesignSystem.Colors.text2)
            Text(subtitle)
                .font(DesignSystem.Typography.bodyLabel)
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
