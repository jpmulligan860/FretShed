// SessionSummaryView.swift
// FretShed — Presentation Layer
//
// Compact results screen — all content fits without scrolling.
// Done button is always visible at the bottom.

import SwiftUI

extension Notification.Name {
    static let showPracticeTab   = Notification.Name("showPracticeTab")
    static let launchQuiz        = Notification.Name("launchQuiz")
}

public struct SessionSummaryView: View {

    let vm: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.appContainer) private var container
    @State private var attempts: [Attempt] = []
    @State private var insightCard: InsightCard?

    // All three actions are direct closures — no NotificationCenter dispatch.
    // ContentView passes these when embedding the view in QuizSessionView.
    var onDone: (() -> Void)? = nil
    var onViewProgress: (() -> Void)? = nil
    var onRepeat: (() -> Void)? = nil

    private var accuracy: Double {
        guard vm.attemptCount > 0 else { return 0 }
        return Double(vm.correctCount) / Double(vm.attemptCount)
    }

    public var body: some View {
        // Use a plain Group rather than ZStack { Color.ignoresSafeArea() ... }.
        // The ZStack+ignoresSafeArea pattern causes the ZStack to expand to fill
        // the entire screen including safe areas, which in turn can affect how
        // the inner ScrollView calculates its content frame.  On iOS 26 with the
        // Liquid Glass floating tab bar this leaves the Done / View Progress /
        // Repeat buttons in an area the system does not deliver taps to.
        // Background is applied as a view modifier instead, which is the
        // correct SwiftUI idiom for a full-bleed background colour.
        Group {
            if vSizeClass == .compact {
                // Landscape: trophy/badge left, stats + heatmap right
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Spacer()
                        trophyHeader
                        masteryBadge
                        if !attempts.isEmpty {
                            positionsStat
                        }
                        Spacer()
                        buttonStack
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().padding(.vertical, 20)

                    ScrollView {
                        VStack(spacing: 16) {
                            statsGrid
                            if !attempts.isEmpty {
                                SessionHeatmapView(attempts: attempts, fretboardMap: container.fretboardMap)
                            }
                            insightCardView
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Portrait: scrollable stats above, buttons pinned at bottom.
                // Buttons are OUTSIDE the ScrollView so iOS 26's scroll
                // gesture recogniser cannot intercept their taps.
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            trophyHeader
                                .padding(.top, 32)

                            statsGrid
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            if !attempts.isEmpty {
                                SessionHeatmapView(attempts: attempts, fretboardMap: container.fretboardMap)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                            }

                            masteryBadge
                                .padding(.top, 16)

                            if !attempts.isEmpty {
                                positionsStat
                                    .padding(.top, 8)
                            }

                            insightCardView
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }
                        .padding(.bottom, 16)
                    }

                    buttonStack
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .task {
            attempts = (try? container.attemptRepository.attempts(forSession: vm.session.id)) ?? []
            // Generate insight card
            let engine = SessionInsightEngine()
            let allSessions = (try? container.sessionRepository.allSessions()) ?? []
            let masteryScores = (try? container.masteryRepository.allScores()) ?? []
            let baselineLevel = BaselineLevel.load() ?? .startingFresh
            insightCard = engine.insightForSummary(
                session: vm.session,
                sessionAttempts: attempts,
                allSessions: allSessions,
                masteryScores: masteryScores,
                baselineLevel: baselineLevel
            )
        }
    }

    // MARK: - Sub-Views

    private var trophyHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: trophyIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: true)
            }

            Text(trophyTitle)
                .font(DesignSystem.Typography.screenTitle)
                .foregroundStyle(.white)

            Text(trophySubtitle)
                .font(DesignSystem.Typography.accentDescription)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            switch vm.session.gameMode {
            case .streak:
                StatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: DesignSystem.Colors.amber)
                StatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: DesignSystem.Colors.correct)
                StatCard(label: "Accuracy",    value: "\(Int(accuracy * 100))%",   icon: "target",           color: accuracyColor)
                StatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: DesignSystem.Colors.cherry)
            default:
                StatCard(label: "Accuracy",    value: "\(Int(accuracy * 100))%",   icon: "target",           color: accuracyColor)
                StatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: DesignSystem.Colors.cherry)
                StatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame",            color: DesignSystem.Colors.amber)
                StatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: DesignSystem.Colors.correct)
            }
        }
    }

    private var masteryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
            Text(vm.session.masteryLevel.localizedLabel)
        }
        .font(DesignSystem.Typography.bodyLabel)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(masteryColor.opacity(0.15), in: Capsule())
        .foregroundStyle(masteryColor)
    }

    private var buttonStack: some View {
        VStack(spacing: 10) {
            doneButton
            HStack(spacing: 12) {
                viewProgressButton
                repeatButton
            }
        }
    }

    private var doneButton: some View {
        Button {
            onDone?()
        } label: {
            Text("Back to The Shed")
                .font(DesignSystem.Typography.screenTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(DesignSystem.Gradients.primary, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var viewProgressButton: some View {
        Button {
            onViewProgress?()
        } label: {
            Label("View Journey", systemImage: "chart.bar.fill")
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(DesignSystem.Colors.cherry)
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.leading, 20)
    }

    private var repeatButton: some View {
        Button {
            onRepeat?()
        } label: {
            Label("Repeat", systemImage: "arrow.counterclockwise")
                .font(DesignSystem.Typography.bodyLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(DesignSystem.Colors.correct)
                .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
    }

    // MARK: - Insight Card

    @ViewBuilder
    private var insightCardView: some View {
        if let card = insightCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: card.isMilestone ? "trophy.fill" : "brain")
                        .foregroundStyle(card.isMilestone ? DesignSystem.Colors.gold : DesignSystem.Colors.amber)
                    Text(card.isMilestone ? "MILESTONE" : "INSIGHT")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(card.isMilestone ? DesignSystem.Colors.gold : DesignSystem.Colors.amber)
                        .tracking(1.0)
                }

                Text(card.headline)
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundStyle(DesignSystem.Colors.text)

                if let body = card.body {
                    Text(body)
                        .font(DesignSystem.Typography.accentDescription)
                        .foregroundStyle(DesignSystem.Colors.text2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .woodshopCard()
            .overlay(
                card.isMilestone
                    ? RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(DesignSystem.Colors.gold.opacity(0.5), lineWidth: 2)
                    : nil
            )
        }
    }

    // MARK: - Computed

    private var uniquePositionCount: Int {
        Set(attempts.map { "\($0.targetString)-\($0.targetFret)" }).count
    }

    private var positionsStat: some View {
        Label(
            "\(uniquePositionCount) fretboard position\(uniquePositionCount == 1 ? "" : "s") practiced",
            systemImage: "square.grid.3x3.fill"
        )
        .font(DesignSystem.Typography.smallLabel)
        .foregroundStyle(DesignSystem.Colors.text2)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.surface2, in: Capsule())
    }

    private var trophyIcon: String {
        if accuracy >= 0.9 { return "trophy.fill" }
        if accuracy >= 0.7 { return "star.fill" }
        return "hand.thumbsup.fill"
    }

    private var trophyColor: Color {
        if accuracy >= 0.9 { return DesignSystem.Colors.honey }
        if accuracy >= 0.7 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.cherry
    }

    private var trophyTitle: String {
        switch vm.session.gameMode {
        case .streak:
            if vm.bestStreak >= 20 { return "Unstoppable!" }
            if vm.bestStreak >= 10 { return "On Fire!" }
            if vm.bestStreak >= 5  { return "Nice Run!" }
            return "Keep Pushing!"
        default:
            if accuracy >= 0.9 { return "Outstanding!" }
            if accuracy >= 0.7 { return "Great Work!" }
            if accuracy >= 0.5 { return "Good Effort!" }
            return "Keep At It!"
        }
    }

    private var trophySubtitle: String {
        switch vm.session.gameMode {
        case .streak:
            return "You answered \(vm.bestStreak) in a row without a mistake."
        default:
            if accuracy >= 0.9 { return "You're mastering the fretboard." }
            if accuracy >= 0.7 { return "Your knowledge is growing steadily." }
            if accuracy >= 0.5 { return "Each session builds muscle memory." }
            return "Every rep gets you closer. Stick with it."
        }
    }

    private var accuracyColor: Color {
        if accuracy >= 0.8 { return DesignSystem.Colors.correct }
        if accuracy >= 0.6 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    private var masteryColor: Color {
        DesignSystem.Colors.masteryColor(for: vm.session.overallMasteryAtEnd)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(DesignSystem.Typography.dataDisplay)
                .foregroundStyle(DesignSystem.Colors.text)
            Text(label)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .woodshopCard()
    }
}
