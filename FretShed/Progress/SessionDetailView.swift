// SessionDetailView.swift
// FretShed — Presentation Layer
//
// Historical session review view presented as a sheet from the Progress tab.

import SwiftUI

struct SessionDetailView: View {

    let detail: SessionDetail
    @Environment(\.appContainer) private var container

    private var session: Session { detail.session }
    private var attempts: [Attempt] { detail.attempts }

    private var accuracy: Double {
        guard session.attemptCount > 0 else { return 0 }
        return Double(session.correctCount) / Double(session.attemptCount)
    }

    private var avgResponseTimeMs: Int {
        let correctTimes = attempts.filter { $0.wasCorrect }.map { $0.responseTimeMs }
        guard !correctTimes.isEmpty else { return 0 }
        return correctTimes.reduce(0, +) / correctTimes.count
    }

    private var bestStreak: Int {
        var current = 0
        var best = 0
        for attempt in attempts.sorted(by: { $0.timestamp < $1.timestamp }) {
            if attempt.wasCorrect {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    header
                        .padding(.top, 8)

                    // Stats
                    statsRow
                        .padding(.horizontal, 20)

                    // Heatmap
                    if !attempts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FRETBOARD HEATMAP")
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(DesignSystem.Colors.text2)
                                .padding(.horizontal, 20)
                            SessionHeatmapView(
                                attempts: attempts,
                                fretboardMap: container.fretboardMap,
                                availableWidth: geo.size.width - 32
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: modeIcon)
                .font(.system(size: 40))
                .foregroundStyle(modeColor)
                .frame(width: 64, height: 64)
                .background(modeColor.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))

            HStack(spacing: 6) {
                Text(session.focusMode.localizedLabel)
                    .font(.title3.bold())
                if session.isAdaptive {
                    Image(systemName: "brain")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.gold)
                }
            }

            HStack(spacing: 8) {
                Text(session.startTime, style: .date)
                Text("·")
                Text(durationLabel(session.duration))
            }
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.text2)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            SessionStatCard(label: "Accuracy", value: "\(Int(accuracy * 100))%",
                            icon: "target", color: accuracyColor)
            if session.gameMode == .timed, avgResponseTimeMs > 0 {
                SessionStatCard(label: "Avg Time",
                                value: String(format: "%.1fs", Double(avgResponseTimeMs) / 1000.0),
                                icon: "clock.fill", color: DesignSystem.Colors.amber)
            } else {
                SessionStatCard(label: "Questions", value: "\(session.attemptCount)",
                                icon: "list.number", color: DesignSystem.Colors.cherry)
            }
            SessionStatCard(label: "Best Streak", value: "\(bestStreak)",
                            icon: "flame.fill", color: DesignSystem.Colors.amber)
            SessionStatCard(label: "Correct", value: "\(session.correctCount)",
                            icon: "checkmark.circle", color: DesignSystem.Colors.correct)
        }
    }

    // MARK: - Helpers

    private var accuracyColor: Color {
        if accuracy >= 0.8 { return DesignSystem.Colors.correct }
        if accuracy >= 0.6 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }

    private var modeIcon: String {
        switch session.focusMode {
        case .fullFretboard:     return "rectangle.grid.3x2"
        case .singleNote:        return "music.note"
        case .circleOfFifths:    return "circle.dashed"
        case .circleOfFourths:   return "circle.grid.2x1"
        case .singleString:      return "minus"
        case .chordProgression:  return "pianokeys"
        case .fretboardPosition: return "slider.horizontal.3"
        }
    }

    private var modeColor: Color {
        switch session.focusMode {
        case .fullFretboard:     return DesignSystem.Colors.cherry
        case .singleNote:        return DesignSystem.Colors.amber
        case .circleOfFifths:    return DesignSystem.Colors.honey
        case .fretboardPosition: return DesignSystem.Colors.gold
        case .circleOfFourths,
             .singleString,
             .chordProgression:  return DesignSystem.Colors.amber
        }
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}

// MARK: - SessionStatCard

private struct SessionStatCard: View {
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
                .font(DesignSystem.Typography.screenTitle)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}
