// ContentView.swift
// FretMaster — App Layer
//
// Root TabView.
// Four tabs: Practice, Progress, Tuner, Settings.
// Phase 3: Practice tab — complete.
// Phase 4: Progress tab — complete.
// Phase 5: Tuner + live mic in quiz — complete.
// Phase 6: Settings — complete.

import SwiftUI
import Combine

struct ContentView: View {

    @Environment(\.appContainer) private var container
    @State private var selectedTab: Tab = .practice
    @State private var showSetup = false

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
        TabView(selection: $selectedTab) {
            // ── Practice ──────────────────────────────────────────────
            practiceTab
                .tabItem { Label(Tab.practice.rawValue, systemImage: Tab.practice.icon) }
                .tag(Tab.practice)

            // ── Progress ──────────────────────────────────────────────
            progressTabView
                .tabItem { Label(Tab.progress.rawValue, systemImage: Tab.progress.icon) }
                .tag(Tab.progress)

            // ── Tuner ─────────────────────────────────────────────────
            tunerTabView
                .tabItem { Label(Tab.tuner.rawValue, systemImage: Tab.tuner.icon) }
                .tag(Tab.tuner)

            // ── MetroDrone ───────────────────────────────────────────
            MetroDroneView()
                .tabItem { Label(Tab.metroDrone.rawValue, systemImage: Tab.metroDrone.icon) }
                .tag(Tab.metroDrone)

            // ── Settings ──────────────────────────────────────────────
            settingsStubView
                .tabItem { Label(Tab.settings.rawValue, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
        .fullScreenCover(isPresented: $showSetup) {
            SessionSetupView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProgressTab)) { _ in
            showSetup = false
            selectedTab = .progress
        }
    }

    // MARK: - Practice Tab

    private var practiceTab: some View {
        NavigationStack {
            PracticeHomeView(onStartPractice: { showSetup = true })
                .navigationTitle("FretMaster")
                .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Progress Tab (Phase 4)

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

    // MARK: - Stub Views (replaced in Phase 6)

    private var tunerTabView: some View {
        TunerView()
    }

    private var settingsStubView: some View {
        SettingsView()
    }
}

// MARK: - PracticeHomeView

/// Landing page inside the Practice tab.
struct PracticeHomeView: View {

    let onStartPractice: () -> Void
    @Environment(\.appContainer) private var container
    @State private var lastSession: Session?
    @State private var activeQuizVM: QuizViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Hero card
                heroCard

                // Quick-start buttons
                quickStartGrid

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: 800) // Cap width on large screens / landscape iPad
            .frame(maxWidth: .infinity)
        }
        .task {
            lastSession = try? container.sessionRepository.recentSessions(limit: 1).first
        }
        .fullScreenCover(item: $activeQuizVM) { vm in
            QuizView(vm: vm)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color.purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)

            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to practice?")
                    .font(.title2.bold())
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
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK START")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Use 4 columns in wide/landscape layouts, 2 in compact
            ViewThatFits(in: .horizontal) {
                LazyVGrid(columns: [.init(), .init(), .init(), .init()], spacing: 12) {
                    if lastSession != nil {
                        repeatLastCard
                    }
                    ForEach([FocusMode.singleNote, .singleString, .fullFretboard], id: \.self) { mode in
                        QuickModeCard(mode: mode, onTap: { quickLaunch(focusMode: mode) })
                    }
                }
                LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                    if lastSession != nil {
                        repeatLastCard
                    }
                    ForEach([FocusMode.singleNote, .singleString, .fullFretboard], id: \.self) { mode in
                        QuickModeCard(mode: mode, onTap: { quickLaunch(focusMode: mode) })
                    }
                }
            }
        }
    }

    private var repeatLastCard: some View {
        Button(action: repeatLastSession) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Repeat Last")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func quickLaunch(focusMode: FocusMode) {
        let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
        let session = Session(
            focusMode: focusMode,
            gameMode: settings.defaultGameMode
        )
        settings.defaultSessionLength = 20
        Task {
            try? container.sessionRepository.save(session)
            let vm = QuizViewModel(
                session: session,
                fretboardMap: container.fretboardMap,
                settings: settings,
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                attemptRepository: container.attemptRepository
            )
            activeQuizVM = vm
        }
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
        Task {
            try? container.sessionRepository.save(session)
            let settings = (try? container.settingsRepository.loadSettings()) ?? UserSettings()
            settings.defaultSessionLength = prev.attemptCount > 0 ? prev.attemptCount : 20
            let vm = QuizViewModel(
                session: session,
                fretboardMap: container.fretboardMap,
                settings: settings,
                masteryRepository: container.masteryRepository,
                sessionRepository: container.sessionRepository,
                attemptRepository: container.attemptRepository
            )
            activeQuizVM = vm
        }
    }
}

// MARK: - QuickModeCard

private struct QuickModeCard: View {
    let mode: FocusMode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: modeIcon)
                    .font(.title2)
                    .foregroundStyle(modeColor)
                Text(mode.localizedLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
        case .fullFretboard:      return .indigo
        case .fretboardPosition:  return .teal
        case .singleNote:         return .blue
        case .circleOfFifths:     return .orange
        case .singleString:       return .teal
        default:                  return .teal
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
