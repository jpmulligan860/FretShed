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
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        SessionHeatmapView(attempts: attempts, fretboardMap: container.fretboardMap)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
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
                        .foregroundStyle(.purple)
                }
            }

            HStack(spacing: 8) {
                Text(session.startTime, style: .date)
                Text("·")
                Text(durationLabel(session.duration))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            SessionStatCard(label: "Accuracy", value: "\(Int(accuracy * 100))%",
                            icon: "target", color: accuracyColor)
            SessionStatCard(label: "Questions", value: "\(session.attemptCount)",
                            icon: "list.number", color: .blue)
            SessionStatCard(label: "Best Streak", value: "\(bestStreak)",
                            icon: "flame.fill", color: .orange)
            SessionStatCard(label: "Correct", value: "\(session.correctCount)",
                            icon: "checkmark.circle", color: .green)
        }
    }

    // MARK: - Helpers

    private var accuracyColor: Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.6 { return .orange }
        return .red
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
        case .fullFretboard:     return DesignSystem.Colors.primary
        case .singleNote:        return .blue
        case .circleOfFifths:    return .orange
        case .fretboardPosition: return .cyan
        case .circleOfFourths,
             .singleString,
             .chordProgression:  return DesignSystem.Colors.secondary
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
                .font(DesignSystem.Typography.title)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }
}
