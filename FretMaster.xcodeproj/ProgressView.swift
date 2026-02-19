// ProgressView.swift
// FretMaster — Presentation Layer (Phase 4)
//
// The Progress tab root view.
// ┌──────────────────────────────────────────┐
// │  Overall mastery ring  +  summary stats  │
// │  6×12 mastery heatmap  (tap → detail)    │
// │  Recent sessions list                    │
// └──────────────────────────────────────────┘

import SwiftUI

public struct ProgressTabView: View {

    @State private var vm: ProgressViewModel
    @Environment(\.appContainer) private var container

    public init(vm: ProgressViewModel) {
        _vm = State(initialValue: vm)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Overall mastery card ──────────────────────────────
                overallCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // ── Heatmap ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("FRETBOARD MASTERY")
                        .padding(.horizontal, 16)

                    MasteryHeatmapView(vm: vm)
                        .padding(.horizontal, 16)

                    HeatmapLegend()
                        .padding(.horizontal, 20)
                }

                // ── Recent sessions ───────────────────────────────────
                if !vm.recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("RECENT SESSIONS")
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(vm.recentSessions.enumerated()), id: \.element.id) { idx, session in
                                SessionRow(session: session)
                                if idx < vm.recentSessions.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if vm.isLoading {
                ProgressIndicatorOverlay()
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $vm.selectedCell) { detail in
            CellDetailSheet(detail: detail)
        }
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        HStack(spacing: 20) {
            // Big mastery ring
            OverallMasteryRing(value: vm.overallMastery)
                .frame(width: 100, height: 100)

            // Summary stats
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(
                    icon: "square.grid.3x3.fill",
                    label: "Cells attempted",
                    value: "\(vm.attemptedCells) / \(ProgressViewModel.totalCells)",
                    color: .indigo
                )
                summaryRow(
                    icon: "checkmark.seal.fill",
                    label: "Mastered",
                    value: "\(vm.masteredCells) cells",
                    color: .green
                )
                summaryRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Overall mastery",
                    value: "\(Int(vm.overallMastery * 100))%",
                    color: masteryColor(vm.overallMastery)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func masteryColor(_ score: Double) -> Color {
        switch MasteryLevel.from(score: score) {
        case .mastered:   return .green
        case .proficient: return .blue
        case .developing: return .orange
        case .beginner:   return .red
        }
    }
}

// MARK: - OverallMasteryRing

private struct OverallMasteryRing: View {

    let value: Double   // 0–1

    private var ringColor: Color {
        switch MasteryLevel.from(score: value) {
        case .mastered:   return .green
        case .proficient: return .blue
        case .developing: return .orange
        case .beginner:   return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(ringColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.8), value: value)

            VStack(spacing: 0) {
                Text("\(Int(value * 100))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - SessionRow

private struct SessionRow: View {

    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            // Mode icon
            Image(systemName: modeIcon(session.focusMode))
                .font(.title3)
                .foregroundStyle(modeColor(session.focusMode))
                .frame(width: 36, height: 36)
                .background(modeColor(session.focusMode).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.focusMode.localizedLabel)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    Text(session.startTime, style: .date)
                    Text("·")
                    Text(durationLabel(session.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.accuracyPercent))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accuracyColor(session.accuracyPercent))
                Text("\(session.correctCount)/\(session.attemptCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    private func modeIcon(_ mode: FocusMode) -> String {
        switch mode {
        case .fullFretboard:    return "rectangle.grid.3x2"
        case .singleNote:       return "music.note"
        case .circleOfFifths:   return "circle.dashed"
        case .circleOfFourths:  return "circle.grid.2x1"
        case .singleString:     return "minus"
        case .chordProgression: return "pianokeys"
        case .fretboardPosition: return "slider.horizontal.3"
        }
    }

    private func modeColor(_ mode: FocusMode) -> Color {
        switch mode {
        case .fullFretboard:    return .indigo
        case .singleNote:       return .blue
        case .circleOfFifths:   return .orange
        default:                return .teal
        }
    }

    private func accuracyColor(_ pct: Double) -> Color {
        if pct >= 80 { return .green }
        if pct >= 60 { return .orange }
        return .red
    }
}

// MARK: - ProgressIndicatorOverlay

private struct ProgressIndicatorOverlay: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.6)
                .ignoresSafeArea()
            ProgressView("Loading…")
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Preview

#Preview {
    let container = AppContainer.makeForTesting()
    let vm = ProgressViewModel(
        masteryRepository: container.masteryRepository,
        sessionRepository: container.sessionRepository,
        attemptRepository: container.attemptRepository
    )
    return NavigationStack {
        ProgressTabView(vm: vm)
    }
    .environment(\.appContainer, container)
}
