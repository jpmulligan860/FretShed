// SessionSummaryView.swift
// FretShed — Presentation Layer
//
// Compact results screen — all content fits without scrolling.
// Done button is always visible at the bottom.

import SwiftUI

extension Notification.Name {
    static let showProgressTab   = Notification.Name("showProgressTab")
    static let showPracticeTab   = Notification.Name("showPracticeTab")
    static let repeatLastSession = Notification.Name("repeatLastSession")
    static let launchQuiz        = Notification.Name("launchQuiz")
    /// Posted by any results-screen button that wants to dismiss the quiz flow.
    /// ContentView receives this and sets activeQuizVM = nil.
    static let dismissQuiz       = Notification.Name("dismissQuiz")
}

public struct SessionSummaryView: View {

    let vm: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.appContainer) private var container
    @State private var attempts: [Attempt] = []

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
        }
    }

    // MARK: - Sub-Views

    private var trophyHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: trophyIcon)
                .font(.system(size: 56))
                .foregroundStyle(trophyColor)
                .symbolEffect(.bounce, value: true)

            Text(trophyTitle)
                .font(DesignSystem.Typography.screenTitle)

            Text(trophySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [trophyColor.opacity(0.12), trophyColor.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
        )
        .padding(.horizontal, 20)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            switch vm.session.gameMode {
            case .streak:
                StatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: .orange)
                StatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: .green)
                StatCard(label: "Accuracy",    value: "\(Int(accuracy * 100))%",   icon: "target",           color: accuracyColor)
                StatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
            case .tempo:
                StatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame.fill",       color: .orange)
                StatCard(label: "Fastest",     value: String(format: "%.1fs", vm.tempoTimeAllowance),
                                                                                    icon: "bolt.fill",        color: .yellow)
                StatCard(label: "Accuracy",    value: "\(Int(accuracy * 100))%",   icon: "target",           color: accuracyColor)
                StatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
            default:
                StatCard(label: "Accuracy",    value: "\(Int(accuracy * 100))%",   icon: "target",           color: accuracyColor)
                StatCard(label: "Questions",   value: "\(vm.attemptCount)",         icon: "list.number",      color: .blue)
                StatCard(label: "Best Streak", value: "\(vm.bestStreak)🔥",        icon: "flame",            color: .orange)
                StatCard(label: "Correct",     value: "\(vm.correctCount)",         icon: "checkmark.circle", color: .green)
            }
        }
    }

    private var masteryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
            Text(vm.session.masteryLevel.localizedLabel)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
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
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.cherry, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    private var viewProgressButton: some View {
        Button {
            onViewProgress?()
        } label: {
            Label("View Progress", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(DesignSystem.Colors.cherry)
        .padding(.leading, 20)
    }

    private var repeatButton: some View {
        Button {
            onRepeat?()
        } label: {
            Label("Repeat", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(DesignSystem.Colors.correct)
        .padding(.trailing, 20)
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
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.surface, in: Capsule())
    }

    private var trophyIcon: String {
        if accuracy >= 0.9 { return "trophy.fill" }
        if accuracy >= 0.7 { return "star.fill" }
        return "hand.thumbsup.fill"
    }

    private var trophyColor: Color {
        if accuracy >= 0.9 { return .yellow }
        if accuracy >= 0.7 { return .orange }
        return .blue
    }

    private var trophyTitle: String {
        switch vm.session.gameMode {
        case .streak:
            if vm.bestStreak >= 20 { return "Unstoppable!" }
            if vm.bestStreak >= 10 { return "On Fire!" }
            if vm.bestStreak >= 5  { return "Nice Run!" }
            return "Keep Pushing!"
        case .tempo:
            if vm.tempoTimeAllowance <= 2.5 { return "Lightning Fast!" }
            if accuracy >= 0.9 { return "Outstanding!" }
            return "Great Tempo!"
        default:
            if accuracy >= 0.9 { return "Outstanding!" }
            if accuracy >= 0.7 { return "Great Work!" }
            if accuracy >= 0.5 { return "Good Effort!" }
            return "Keep Practicing!"
        }
    }

    private var trophySubtitle: String {
        switch vm.session.gameMode {
        case .streak:
            return "You answered \(vm.bestStreak) in a row without a mistake."
        case .tempo:
            return String(format: "You reached a %.1f second time limit per note.", vm.tempoTimeAllowance)
        default:
            if accuracy >= 0.9 { return "You're mastering the fretboard." }
            if accuracy >= 0.7 { return "Your knowledge is growing steadily." }
            if accuracy >= 0.5 { return "Each session builds muscle memory." }
            return "Repetition is the key to mastery."
        }
    }

    private var accuracyColor: Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.6 { return .orange }
        return .red
    }

    private var masteryColor: Color {
        switch vm.session.masteryLevel {
        case .mastered:   return DesignSystem.Colors.masteryMastered
        case .proficient: return DesignSystem.Colors.masteryProficient
        case .developing: return DesignSystem.Colors.masteryDeveloping
        case .beginner:   return DesignSystem.Colors.masteryBeginner
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}
