// PhaseRoadmapSection.swift
// FretShed — Progress Tab
//
// Collapsible phase roadmap showing the user's learning progression.
// UI-only — reads LearningPhaseManager state, no engine changes.

import SwiftUI

// MARK: - Phase Color Helpers

private extension LearningPhase {
    var color: Color {
        switch self {
        case .foundation: return DesignSystem.Colors.cherry
        case .expansion:  return DesignSystem.Colors.amber
        case .connection: return DesignSystem.Colors.gold
        case .fluency:    return DesignSystem.Colors.correct
        }
    }

    var dimBg: Color { color.opacity(0.12) }
    var dimBorder: Color { color.opacity(0.25) }

    var tagline: String {
        switch self {
        case .foundation: return "Natural notes, one string at a time"
        case .expansion:  return "Sharps & flats, one string at a time"
        case .connection: return "Notes across strings"
        case .fluency:    return "Full fretboard, instant recall"
        }
    }

    var descriptionText: String {
        switch self {
        case .foundation:
            return "Most fretboard trainers show you everything at once. FretShed doesn\u{2019}t \u{2014} and that\u{2019}s deliberate. You begin on a single string, focusing only on natural notes: A, B, C, D, E, F, G. Each session clusters 3\u{2013}4 of them into a short scale fragment so they feel musical rather than arbitrary. The same notes come back across multiple sessions, spaced further apart as they stick. It is narrow by design. A small territory known cold is more useful than a large territory known vaguely."
        case .expansion:
            return "Phase 2 follows the same structure as Phase 1, string by string \u{2014} the only difference is what you\u{2019}re finding. You already know where every natural note lives on each string. Sharps and flats are the notes in between, and once the natural notes are anchors, the chromatics slot in quickly. F# stops being abstract when you already know F and G on either side of it."
        case .connection:
            return "With every string solid on its own, sessions now span the neck. The goal of this phase is clear from the start: the fretboard becomes a map rather than a collection of positions. Instead of drilling one string, you\u{2019}re finding notes that belong together across strings \u{2014} C, E, and G on three different strings forming a C major triad. The results screen reveals what you played: not just the notes, but the chord or pattern they outline."
        case .fluency:
            return "Full fretboard, every note, fully interleaved. Note groups now outline chord progressions and arpeggios spread across positions. This is the end state that most fretboard apps start with \u{2014} but by the time you reach it here, you\u{2019}re not thinking about positions at all. The note is under your fingers before you\u{2019}ve consciously looked for it."
        }
    }

    var scopeText: String {
        switch self {
        case .foundation: return "Natural notes only \u{00B7} One string per session"
        case .expansion:  return "Sharps & flats \u{00B7} One string per session"
        case .connection: return "All notes \u{00B7} Cross-string \u{00B7} Triads & octave pairs"
        case .fluency:    return "All notes \u{00B7} Full fretboard \u{00B7} Interleaved"
        }
    }

    var advancesWhenText: String {
        switch self {
        case .foundation: return "Each string advances when its natural notes reach mastery threshold. Phase unlocks when all 6 strings pass."
        case .expansion:  return "Each string advances when its accidentals reach mastery threshold. Phase unlocks when all 6 strings pass."
        case .connection: return "Unlocks when all 6 strings pass Phase 2 thresholds."
        case .fluency:    return "Unlocks when Phase 3 cross-string work reaches mastery threshold."
        }
    }
}

// MARK: - PhaseRoadmapSection

struct PhaseRoadmapSection: View {
    let phaseManager: LearningPhaseManager
    let sessionAccuracy: Double

    @Environment(\.appContainer) private var container
    @State private var isExpanded = false
    @State private var showInfo = false
    @State private var showPhasePaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Section title
            HStack(spacing: 6) {
                Text("SMART PRACTICE PHASE PROGRESS")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            PhaseRoadmapHeader(
                currentPhase: phaseManager.currentPhase,
                completedStrings: completedStringsForCurrentPhase,
                currentString: currentStringForPhase,
                sessionAccuracy: sessionAccuracy,
                isExpanded: isExpanded
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(LearningPhase.allCases, id: \.rawValue) { phase in
                        PhaseRoadmapRow(
                            phase: phase,
                            currentPhase: phaseManager.currentPhase,
                            completedStrings: completedStrings(for: phase),
                            currentString: currentString(for: phase),
                            sessionAccuracy: sessionAccuracy,
                            initiallyExpanded: phase == phaseManager.currentPhase,
                            isPremiumLocked: container.entitlementManager.requiresPremium(for: phase),
                            onPremiumTap: { showPhasePaywall = true }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? phaseManager.currentPhase.dimBorder : DesignSystem.Colors.border, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .sheet(isPresented: $showInfo) {
            PhaseRoadmapInfoSheet()
        }
        .sheet(isPresented: $showPhasePaywall) {
            PaywallView(entitlementManager: container.entitlementManager)
        }
    }

    private var completedStringsForCurrentPhase: Int {
        completedStrings(for: phaseManager.currentPhase)
    }

    private var currentStringForPhase: Int? {
        currentString(for: phaseManager.currentPhase)
    }

    private func completedStrings(for phase: LearningPhase) -> Int {
        switch phase {
        case .foundation: return phaseManager.phaseOneCompletedStrings.count
        case .expansion:  return phaseManager.phaseTwoCompletedStrings.count
        case .connection, .fluency: return 0
        }
    }

    private func currentString(for phase: LearningPhase) -> Int? {
        switch phase {
        case .foundation: return phaseManager.currentTargetString
        case .expansion:  return phaseManager.currentPhaseTwoTargetString
        case .connection, .fluency: return nil
        }
    }
}

// MARK: - PhaseRoadmapHeader

private struct PhaseRoadmapHeader: View {
    let currentPhase: LearningPhase
    let completedStrings: Int
    let currentString: Int?
    let sessionAccuracy: Double
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Phase number pip
            ZStack {
                Circle()
                    .fill(currentPhase.color)
                    .frame(width: 28, height: 28)
                Text("\(currentPhase.rawValue)")
                    .font(DesignSystem.Typography.dataMicro)
                    .foregroundStyle(.white)
            }

            // Phase name + tagline
            VStack(alignment: .leading, spacing: 1) {
                Text(currentPhase.displayName)
                    .font(DesignSystem.Typography.bodyLabel)
                Text(currentPhase.tagline)
                    .font(DesignSystem.Typography.accentDescription)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }

            Spacer()

            // Right side indicator
            rightIndicator

            // Chevron
            Image(systemName: "chevron.down")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.muted)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(14)
    }

    @ViewBuilder
    private var rightIndicator: some View {
        switch currentPhase {
        case .foundation, .expansion:
            StringProgressDots(
                completedCount: completedStrings,
                currentString: currentString,
                phaseColor: currentPhase.color
            )
        case .connection, .fluency:
            // Small accuracy ring
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.amber.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                Circle()
                    .trim(from: 0, to: sessionAccuracy)
                    .stroke(DesignSystem.Colors.amber, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(sessionAccuracy * 100))")
                    .font(DesignSystem.Typography.heatmapLabel)
            }
        }
    }
}

// MARK: - PhaseRoadmapRow

private struct PhaseRoadmapRow: View {
    let phase: LearningPhase
    let currentPhase: LearningPhase
    let completedStrings: Int
    let currentString: Int?
    let sessionAccuracy: Double
    let initiallyExpanded: Bool
    let isPremiumLocked: Bool
    var onPremiumTap: (() -> Void)?

    @State private var isExpanded: Bool

    init(phase: LearningPhase, currentPhase: LearningPhase, completedStrings: Int,
         currentString: Int?, sessionAccuracy: Double, initiallyExpanded: Bool,
         isPremiumLocked: Bool = false, onPremiumTap: (() -> Void)? = nil) {
        self.phase = phase
        self.currentPhase = currentPhase
        self.completedStrings = completedStrings
        self.currentString = currentString
        self.sessionAccuracy = sessionAccuracy
        self.initiallyExpanded = initiallyExpanded
        self.isPremiumLocked = isPremiumLocked
        self.onPremiumTap = onPremiumTap
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var status: PhaseStatus {
        if isPremiumLocked { return .locked }
        if phase.rawValue < currentPhase.rawValue { return .complete }
        if phase == currentPhase { return .active }
        return .locked
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row header
            HStack(spacing: 10) {
                statusBadge
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(phase.displayName)
                            .font(DesignSystem.Typography.bodyLabel)

                        if status == .active {
                            Text("NOW")
                                .font(DesignSystem.Typography.dataChip)
                                .foregroundStyle(phase.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(phase.dimBg, in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(phase.dimBorder, lineWidth: 1))
                        }
                    }
                    Text(phase.tagline)
                        .font(DesignSystem.Typography.accentDescription)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }

                Spacer()

                // Right indicator for active string-based phases
                if status == .active {
                    switch phase {
                    case .foundation, .expansion:
                        StringProgressDots(
                            completedCount: completedStrings,
                            currentString: currentString,
                            phaseColor: phase.color
                        )
                    case .connection, .fluency:
                        ZStack {
                            Circle()
                                .stroke(DesignSystem.Colors.amber.opacity(0.2), lineWidth: 2.5)
                                .frame(width: 20, height: 20)
                            Circle()
                                .trim(from: 0, to: sessionAccuracy)
                                .stroke(DesignSystem.Colors.amber, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(sessionAccuracy * 100))")
                                .font(DesignSystem.Typography.heatmapLabel)
                        }
                    }
                }

                Image(systemName: "chevron.down")
                    .font(DesignSystem.Typography.microLabel)
                    .foregroundStyle(DesignSystem.Colors.muted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                if isPremiumLocked {
                    onPremiumTap?()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expanded detail
            if isExpanded {
                PhaseRoadmapDetail(phase: phase)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
        .opacity(status == .locked ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .active:
            RoundedRectangle(cornerRadius: 8)
                .fill(phase.dimBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(phase.dimBorder, lineWidth: 1)
                )
                .overlay(
                    Text("\(phase.rawValue)")
                        .font(DesignSystem.Typography.dataMicro)
                        .foregroundStyle(phase.color)
                )
        case .complete:
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.correct.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.correct.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.correct)
                )
        case .locked:
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(DesignSystem.Typography.microLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                )
        }
    }
}

private enum PhaseStatus {
    case active, complete, locked
}

// MARK: - PhaseRoadmapDetail

private struct PhaseRoadmapDetail: View {
    let phase: LearningPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(phase.descriptionText)
                .font(DesignSystem.Typography.bodyText)
                .foregroundStyle(DesignSystem.Colors.text2)
                .lineSpacing(1.3)

            chipRow(label: "SCOPE", value: phase.scopeText)
            chipRow(label: "ADVANCES WHEN", value: phase.advancesWhenText)
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(phase.dimBorder, lineWidth: 1)
        )
    }

    private func chipRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(DesignSystem.Typography.dataChip)
                .foregroundStyle(DesignSystem.Colors.muted)
                .tracking(0.8)
            Text(value)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
    }
}

// MARK: - StringProgressDots

private struct StringProgressDots: View {
    let completedCount: Int
    let currentString: Int?
    let phaseColor: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { index in
                    dot(for: index)
                }
            }
            Text("STRING \(completedCount + (currentString != nil ? 1 : 0))/6")
                .font(DesignSystem.Typography.dataTiny)
                .foregroundStyle(DesignSystem.Colors.muted)
        }
    }

    @ViewBuilder
    private func dot(for index: Int) -> some View {
        let isCompleted = index <= completedCount
        let isCurrent = !isCompleted && index == completedCount + 1 && currentString != nil

        Circle()
            .fill(isCompleted ? DesignSystem.Colors.correct : (isCurrent ? phaseColor : DesignSystem.Colors.surface2))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(isCurrent ? phaseColor : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: isCompleted ? DesignSystem.Colors.correct.opacity(0.5) : (isCurrent ? phaseColor.opacity(0.4) : .clear), radius: 2)
    }
}

// MARK: - PhaseRoadmapInfoSheet

private struct PhaseRoadmapInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Smart Practice guides you through four phases, each building on the last. You don't need to think about what to practice \u{2014} the app picks the right notes, the right focus, and the right challenge level for where you are.")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)

                    ForEach(LearningPhase.allCases, id: \.rawValue) { phase in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(phase.color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("\(phase.rawValue)")
                                            .font(DesignSystem.Typography.dataPip)
                                            .foregroundStyle(.white)
                                    )
                                Text("Phase \(phase.rawValue): \(phase.displayName)")
                                    .font(DesignSystem.Typography.bodyLabel)
                            }
                            Text(phase.tagline)
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(DesignSystem.Colors.text2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("How mastery works")
                            .font(DesignSystem.Typography.bodyLabel)
                        Text("A note turns green when you\u{2019}ve named it correctly across multiple practice sessions over several days. One mistake sets you back a step, but never erases all your progress.")
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.text2)
                    }
                    .padding(.top, 4)

                    Text("Tap the roadmap to expand it and see details for each phase.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Smart Practice Phases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
