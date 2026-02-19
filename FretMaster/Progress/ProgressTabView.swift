//
//  ProgressTabView.swift
//  FretMaster
//
//  Created by John Mulligan on 2/15/26.
//


// ProgressTabView.swift
// FretMaster — Presentation Layer (Phase 4)

import SwiftUI
import Charts

public struct ProgressTabView: View {

    @State private var vm: ProgressViewModel
    @Environment(\.appContainer) private var container
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Deletion alert state
    @State private var sessionToDelete: Session? = nil
    @State private var showDeleteAllConfirm = false
    @State private var showMasteryInfo = false

    public init(vm: ProgressViewModel) {
        _vm = State(initialValue: vm)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                if hSizeClass == .regular {
                    // iPad / wide: overall card and heatmap side-by-side
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 20) {
                            overallCard
                            if !vm.accuracyTrend.isEmpty {
                                accuracyChart
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 8) {
                            masterySectionHeader
                            MasteryHeatmapView(vm: vm, fretboardMap: container.fretboardMap)
                            HeatmapLegend()
                                .padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                } else {
                    // iPhone: original stacked layout
                    overallCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if !vm.accuracyTrend.isEmpty {
                        accuracyChart
                            .padding(.horizontal, 16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        masterySectionHeader
                            .padding(.horizontal, 16)
                        MasteryHeatmapView(vm: vm, fretboardMap: container.fretboardMap)
                            .padding(.horizontal, 16)
                        HeatmapLegend()
                            .padding(.horizontal, 20)
                    }
                }

                if !vm.recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            sectionHeader("RECENT SESSIONS")
                            Spacer()
                            Button(role: .destructive) {
                                showDeleteAllConfirm = true
                            } label: {
                                Text("Delete All")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 16)

                        List {
                            ForEach(vm.recentSessions) { session in
                                Button { vm.selectSession(session) } label: {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        sessionToDelete = session
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: CGFloat(vm.recentSessions.count) * 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .sheet(item: $vm.selectedSession) { detail in
            SessionDetailView(detail: detail)
        }
        .sheet(isPresented: $showMasteryInfo) {
            MasteryInfoSheet()
        }
        // Single-session delete confirmation
        .alert("Delete Session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let s = sessionToDelete {
                    Task { await vm.deleteSession(s) }
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This session will be removed from your history. Your heatmap and mastery statistics may change.")
        }
        // Delete-all confirmation
        .alert("Delete All Sessions?", isPresented: $showDeleteAllConfirm) {
            Button("Delete Sessions Only", role: .destructive) {
                Task { await vm.deleteAllSessions() }
            }
            Button("Delete Sessions & Reset Mastery", role: .destructive) {
                Task { await vm.deleteAllSessionsAndScores() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"Delete Sessions Only\" removes your history and recalculates mastery from scratch — your heatmap will be cleared. \"Delete Sessions & Reset Mastery\" performs a full wipe of all data. Neither action can be undone.")
        }
    }

    // MARK: - Accuracy Trend Chart

    private var accuracyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ACCURACY TREND")

            Chart(vm.accuracyTrend) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(Color.indigo)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.3), Color.indigo.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(Color.indigo)
                .symbolSize(30)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v * 100))%")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, vm.accuracyTrend.count / 5))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 160)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        HStack(spacing: 20) {
            OverallMasteryRing(value: vm.overallMastery)
                .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(icon: "square.grid.3x3.fill",
                           label: "Cells attempted",
                           value: "\(vm.attemptedCells) / \(ProgressViewModel.totalCells)",
                           color: .indigo)
                summaryRow(icon: "checkmark.seal.fill",
                           label: "Mastered",
                           value: "\(vm.masteredCells) cells",
                           color: .green)
                summaryRow(icon: "chart.line.uptrend.xyaxis",
                           label: "Overall mastery",
                           value: "\(Int(vm.overallMastery * 100))%",
                           color: masteryColor(vm.overallMastery))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryRow(icon: String, label: String,
                            value: String, color: Color) -> some View {
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
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var masterySectionHeader: some View {
        HStack {
            sectionHeader("FRETBOARD MASTERY")
            Button {
                showMasteryInfo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

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
    let value: Double

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
            Circle().stroke(ringColor.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
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
            Image(systemName: modeIcon(session.focusMode))
                .font(.title3)
                .foregroundStyle(modeColor(session.focusMode))
                .frame(width: 36, height: 36)
                .background(modeColor(session.focusMode).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(session.focusMode.localizedLabel)
                        .font(.subheadline.weight(.semibold))
                    if session.isAdaptive {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
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
        case .fullFretboard:      return "rectangle.grid.3x2"
        case .singleNote:         return "music.note"
        case .circleOfFifths:     return "circle.dashed"
        case .circleOfFourths:    return "circle.grid.2x1"
        case .singleString:       return "minus"
        case .chordProgression:   return "pianokeys"
        case .fretboardPosition:  return "slider.horizontal.3"
        }
    }

    private func modeColor(_ mode: FocusMode) -> Color {
        switch mode {
        case .fullFretboard:      return .indigo
        case .singleNote:         return .blue
        case .circleOfFifths:     return .orange
        case .fretboardPosition:  return .cyan
        case .circleOfFourths,
             .singleString,
             .chordProgression:   return .teal
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
            Color(.systemBackground).opacity(0.6).ignoresSafeArea()
            ProgressView("Loading…")
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - MasteryInfoSheet

private struct MasteryInfoSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let levels: [(String, Color, String, String)] = [
        ("Beginner",   .red,    "0 – 39%",   "You're just getting started with this note. Keep practicing to build recognition."),
        ("Developing", .orange, "40 – 69%",  "You're building familiarity. With more repetition, this note will become second nature."),
        ("Proficient", .blue,   "70 – 89%",  "You know this note well. A few more correct answers and you'll reach mastery."),
        ("Mastered",   .green,  "90 – 100%", "You consistently identify this note correctly. Great work!")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Each cell on the heatmap represents a specific note on a specific string. Your mastery score is calculated from your accuracy history, weighted so recent attempts matter more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(levels, id: \.0) { name, color, range, desc in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.opacity(0.7))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(name).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(range)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("Tap any cell on the heatmap to see detailed stats and recent attempts for that note.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mastery Levels")
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
