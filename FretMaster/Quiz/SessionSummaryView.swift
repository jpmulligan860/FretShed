// SessionSummaryView.swift
// FretMaster — Presentation Layer
//
// Compact results screen — all content fits without scrolling.
// Done button is always visible at the bottom.

import SwiftUI

extension Notification.Name {
    static let showProgressTab = Notification.Name("showProgressTab")
}

public struct SessionSummaryView: View {

    let vm: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.appContainer) private var container
    @State private var attempts: [Attempt] = []
    var onDone: (() -> Void)? = nil

    private var accuracy: Double {
        guard vm.attemptCount > 0 else { return 0 }
        return Double(vm.correctCount) / Double(vm.attemptCount)
    }

    public var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vSizeClass == .compact {
                // Landscape: trophy/badge left, stats + heatmap right
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Spacer()
                        trophyHeader
                        masteryBadge
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
                // Portrait: scrollable stacked layout
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

                        Spacer(minLength: 16)

                        buttonStack
                            .padding(.bottom, 32)
                    }
                }
            }
        }
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
                .font(.title2.bold())

            Text(trophySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
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
            viewProgressButton
        }
    }

    private var doneButton: some View {
        Button {
            onDone?() ?? dismiss()
        } label: {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    private var viewProgressButton: some View {
        Button {
            NotificationCenter.default.post(name: .showProgressTab, object: nil)
            onDone?() ?? dismiss()
        } label: {
            Label("View Progress", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.indigo)
        .padding(.horizontal, 20)
    }

    // MARK: - Computed

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
        case .mastered:   return .green
        case .proficient: return .blue
        case .developing: return .orange
        case .beginner:   return .red
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
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
