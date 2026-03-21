// QuizLaunchCoordinator.swift
// FretShed — App Layer
//
// Owns all quiz-launch, calibration-gate, and tab-selection state.
// Extracted from ContentView to keep the root view focused on layout.
//
// Quiz presentation strategy (unchanged):
//   The quiz is a ZStack overlay ABOVE the TabView.
//   Results are shown inline within QuizView (vm.phase == .complete).
//   All results-screen actions are direct closures — no NotificationCenter.

import SwiftUI

// MARK: - AppTab

enum AppTab: String, CaseIterable {
    case practice   = "Shed"
    case progress   = "Journey"
    case tuner      = "Tuner"
    case metroDrone = "Tempo"
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

// MARK: - QuizLaunchCoordinator

@MainActor @Observable
final class QuizLaunchCoordinator {

    // MARK: Tab

    var selectedTab: AppTab = .practice

    // MARK: Quiz Presentation

    var showSetup = false
    var activeQuizVM: QuizViewModel?

    // MARK: Calibration

    var showCalibration = false
    var calibrationForceNewProfile = false
    var showCalibrationGate = false

    // MARK: Last Completed Session

    /// The most recently completed session — updated when any quiz finishes.
    /// PracticeHomeView reads this for the "Repeat Last" tile and seeds it from DB on first load.
    var lastCompletedSession: Session?

    /// Set to true after a quiz ends so the progress tab reloads fresh data.
    /// ContentView observes this and triggers a reload on ProgressViewModel.
    var needsProgressReload = false

    // MARK: Phase Context (for results screen)

    /// The learning phase before the quiz started — used to detect phase advancement.
    var phaseBeforeQuiz: LearningPhase?

    /// Musical context from the last Smart Practice session plan.
    var lastSessionGroups: [NoteGroup]?

    /// Next session recommendation text, set after quiz completes.
    var nextSessionRecommendation: String?

    /// Pre-built next session, so the "Next Up" button launches exactly what was described.
    /// Set at the same time as nextSessionRecommendation in loadPhaseContext().
    var nextSessionPrebuilt: Session?
    var nextSessionGroups: [NoteGroup]?

    // MARK: Internal

    var pendingQuizVM: QuizViewModel?
    var pendingTapMode = false
    var tapModeWasForced = false
    var gatedQuizVM: QuizViewModel?

    // MARK: Dependencies

    /// Set by ContentView in `.task` — available before any user interaction.
    var container: AppContainer!

    private var hasCompletedCalibration: Bool {
        UserDefaults.standard.bool(forKey: LocalUserPreferences.Key.hasCompletedCalibration)
    }

    // MARK: - Quiz Launch

    func launchQuiz(vm: QuizViewModel) {
        guard hasCompletedCalibration || vm.settings.tapToAnswerEnabled || vm.settings.tapModeEnabled else {
            gatedQuizVM = vm
            showCalibrationGate = true
            return
        }
        selectedTab = .practice
        activeQuizVM = vm
    }

    func launchRepeatSession(from session: Session) async {
        let targetNotes = session.notes.compactMap { MusicalNote(rawValue: $0) }
        let newSession = Session(
            focusMode: session.focusMode,
            gameMode: session.gameMode,
            fretRangeStart: session.fretRangeStart,
            fretRangeEnd: session.fretRangeEnd,
            targetNotes: targetNotes,
            targetStrings: session.targetStrings,
            chordProgression: session.chordProgression,
            isAdaptive: session.isAdaptive,
            sessionTimeLimitSeconds: session.sessionTimeLimitSeconds
        )
        // Route through launchSession to ensure phaseBeforeQuiz is captured
        launchSession(newSession)
    }

    // MARK: - Event Handlers

    /// Called when SessionSetupView dismisses.
    func handleSetupDismiss() {
        guard let vm = pendingQuizVM else {
            pendingTapMode = false
            return
        }
        pendingQuizVM = nil
        launchQuiz(vm: vm)
    }

    /// Called from `.launchQuiz` notification (posted by PracticeHomeView).
    func handleLaunchNotification(vm: QuizViewModel) {
        if pendingTapMode {
            vm.settings.tapToAnswerEnabled = true
            tapModeWasForced = true
            pendingTapMode = false
        }
        if showSetup {
            pendingQuizVM = vm
            showSetup = false
        } else {
            launchQuiz(vm: vm)
        }
    }

    /// Called when CalibrationView dismisses.
    func handleCalibrationDismiss() {
        guard hasCompletedCalibration else { return }
        if let vm = gatedQuizVM {
            gatedQuizVM = nil
            launchQuiz(vm: vm)
        } else {
            selectedTab = .practice
        }
    }

    // MARK: Quiz Overlay Actions

    func handleQuizDone(vm: QuizViewModel) {
        if tapModeWasForced {
            vm.settings.tapToAnswerEnabled = false
            tapModeWasForced = false
        }
        lastCompletedSession = vm.session
        activeQuizVM = nil
        phaseBeforeQuiz = nil
        nextSessionPrebuilt = nil
        nextSessionGroups = nil
        needsProgressReload = true
    }

    func handleViewProgress(vm: QuizViewModel) {
        if tapModeWasForced {
            vm.settings.tapToAnswerEnabled = false
            tapModeWasForced = false
        }
        lastCompletedSession = vm.session
        activeQuizVM = nil
        phaseBeforeQuiz = nil
        nextSessionPrebuilt = nil
        nextSessionGroups = nil
        selectedTab = .progress
        needsProgressReload = true
    }

    func handleQuizRepeat(vm: QuizViewModel) {
        if tapModeWasForced {
            vm.settings.tapToAnswerEnabled = false
            tapModeWasForced = false
        }
        let session = vm.session
        lastCompletedSession = session
        activeQuizVM = nil
        phaseBeforeQuiz = nil
        nextSessionPrebuilt = nil
        nextSessionGroups = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            await launchRepeatSession(from: session)
        }
    }

    func handleNextSession(vm: QuizViewModel, targetNotes: [MusicalNote]? = nil) {
        if tapModeWasForced {
            vm.settings.tapToAnswerEnabled = false
            tapModeWasForced = false
        }
        lastCompletedSession = vm.session
        activeQuizVM = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))

            // If we have specific target notes (e.g. close-to-level-up), build a focused session
            if let notes = targetNotes, !notes.isEmpty {
                let session = Session(
                    focusMode: .singleNote,
                    gameMode: .untimed,
                    targetNotes: notes
                )
                phaseBeforeQuiz = LearningPhaseManager().currentPhase
                lastSessionGroups = nil
                launchSession(session)
                return
            }

            // Use the pre-built session from loadPhaseContext() so the launched session
            // matches exactly what was described in the "Next Up" recommendation.
            if let prebuilt = nextSessionPrebuilt {
                phaseBeforeQuiz = LearningPhaseManager().currentPhase
                lastSessionGroups = nextSessionGroups
                nextSessionPrebuilt = nil
                nextSessionGroups = nil
                launchSession(prebuilt)
                return
            }

            // Fallback: build a fresh session (should rarely happen)
            phaseBeforeQuiz = LearningPhaseManager().currentPhase
            let engine = SmartPracticeEngine(
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                fretboardMap: container.fretboardMap
            )
            guard let (session, _) = try? engine.nextSession() else { return }
            lastSessionGroups = engine.lastSessionPlan?.groups
            launchSession(session)
        }
    }

    // MARK: Calibration Gate Actions

    func handleCalibrateNow() {
        showCalibration = true
    }

    func handleUseTapModeFromGate() {
        if let vm = gatedQuizVM {
            vm.settings.tapToAnswerEnabled = true
            tapModeWasForced = true
            gatedQuizVM = nil
            selectedTab = .practice
            activeQuizVM = vm
        } else {
            pendingTapMode = true
            showSetup = true
        }
    }

    func handleCancelGate() {
        gatedQuizVM = nil
    }

    // MARK: Practice Tab Actions

    func handleStartPractice() {
        guard hasCompletedCalibration else {
            showCalibrationGate = true
            return
        }
        showSetup = true
    }

    func handleSetupAudio() {
        calibrationForceNewProfile = false
        showCalibration = true
    }

    func handleCreateNewProfile() {
        calibrationForceNewProfile = true
        showCalibration = true
    }

    func handleUseTapModeFromHome() {
        pendingTapMode = true
        showSetup = true
    }

    func handleCalibrateAudio() {
        showCalibration = true
    }

    func handleBuildCustomSession() {
        showSetup = true
    }

    /// Launches a session directly from a pre-built Session object (Smart Practice, presets, timed).
    func launchSession(_ session: Session) {
        // Capture current phase before quiz so results screen can detect advancement
        if phaseBeforeQuiz == nil {
            phaseBeforeQuiz = LearningPhaseManager().currentPhase
        }
        let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
        try? container.sessionRepository.save(session)
        let vm = QuizViewModel(
            session: session,
            fretboardMap: container.fretboardMap,
            settings: settings,
            masteryRepository: container.masteryRepository,
            sessionRepository: container.sessionRepository,
            attemptRepository: container.attemptRepository,
            isPremium: container.entitlementManager.isPremium
        )
        launchQuiz(vm: vm)
    }
}
