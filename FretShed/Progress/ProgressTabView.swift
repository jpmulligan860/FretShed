//
//  ProgressTabView.swift
//  FretShed
//
//  Created by John Mulligan on 2/15/26.
//


// ProgressTabView.swift
// FretShed — Presentation Layer (Phase 4)

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
    @State private var showOverallInfo = false
    @State private var showAccuracyInfo = false
    @State private var showResponseTimeInfo = false
    @State private var showSessionsInfo = false

    @AppStorage(LocalUserPreferences.Key.defaultFretCount)
    private var defaultFretCount: Int = LocalUserPreferences.Default.defaultFretCount

    private var totalCells: Int {
        container.fretboardMap.uniqueCellCount(fretCount: defaultFretCount)
    }

    private var activeFilterLabel: String {
        if let focus = vm.focusModeFilter {
            return "Filtered: \(focus.localizedLabel)"
        }
        if let game = vm.gameModeFilter {
            return "Filtered: \(game.localizedLabel)"
        }
        return "Filter Results"
    }

    public init(vm: ProgressViewModel) {
        _vm = State(initialValue: vm)
    }

    public var body: some View {
        GeometryReader { geo in
            Group {
                if vm.loadFailed {
                    dataLoadErrorState
                } else if !vm.isLoading && vm.recentSessions.isEmpty && vm.attemptedCells == 0 {
                    progressEmptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {

                            if hSizeClass == .regular {
                                // iPad / wide: streak/filter row + overall card and heatmap side-by-side
                                streakFilterRow

                                HStack(alignment: .top, spacing: 16) {
                                    VStack(spacing: 20) {
                                        overallCard
                                    }
                                    .frame(maxWidth: .infinity)

                                    VStack(alignment: .leading, spacing: 8) {
                                        masterySectionHeader
                                        MasteryHeatmapView(
                                            vm: vm,
                                            fretboardMap: container.fretboardMap,
                                            availableWidth: (geo.size.width - 48) / 2
                                        )
                                        HeatmapLegend()
                                            .padding(.horizontal, 4)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                                if !vm.accuracyTrend.isEmpty {
                                    accuracyChart
                                        .padding(.horizontal, 16)
                                }

                                if !vm.responseTimeTrend.isEmpty {
                                    responseTimeChart
                                        .padding(.horizontal, 16)
                                }
                            } else {
                                // iPhone: stacked layout
                                // Order: Streak/Filter → Overall → Fretboard Mastery → Accuracy Trend → Avg Response Time
                                streakFilterRow

                                overallCard
                                    .padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 8) {
                                    masterySectionHeader
                                        .padding(.horizontal, 16)
                                    MasteryHeatmapView(
                                        vm: vm,
                                        fretboardMap: container.fretboardMap,
                                        availableWidth: geo.size.width - 32
                                    )
                                    .padding(.horizontal, 16)
                                    HeatmapLegend()
                                        .padding(.horizontal, 20)
                                }

                                if !vm.accuracyTrend.isEmpty {
                                    accuracyChart
                                        .padding(.horizontal, 16)
                                }

                                if !vm.responseTimeTrend.isEmpty {
                                    responseTimeChart
                                        .padding(.horizontal, 16)
                                }
                            }

                            // Recent sessions (VStack replaces List to avoid
                            // List-inside-ScrollView issues on iOS 26)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    sectionHeader("RECENT SESSIONS")
                                    infoButton { showSessionsInfo = true }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)

                                if vm.filteredSessions.isEmpty {
                                    if vm.isAnyFilterActive {
                                        filteredEmptyState
                                    } else {
                                        sessionEmptyState
                                    }
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(vm.filteredSessions) { session in
                                            SessionRow(session: session)
                                                .contentShape(Rectangle())
                                                .onTapGesture { vm.selectSession(session) }

                                            if session.id != vm.filteredSessions.last?.id {
                                                Divider().padding(.horizontal, 16)
                                            }
                                        }
                                    }
                                    .background(
                                        Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .padding(.horizontal, 16)
                                }

                                if !vm.recentSessions.isEmpty {
                                    Button(role: .destructive) {
                                        showDeleteAllConfirm = true
                                    } label: {
                                        Text("Delete All Sessions")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.red)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                                }
                            }

                            Spacer(minLength: 24)
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.recentSessions.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .sheet(item: $vm.selectedCell) { detail in
            CellDetailSheet(detail: detail)
        }
        .sheet(item: $vm.selectedSession) { detail in
            SessionDetailView(detail: detail)
        }
        .sheet(isPresented: $showMasteryInfo) {
            MasteryInfoSheet()
        }
        .sheet(isPresented: $showOverallInfo) {
            ProgressInfoSheet(
                title: "Overall Results",
                items: [
                    ("Cells Attempted", "The number of unique note+string positions you have practiced out of \(totalCells) total cells on your \(defaultFretCount)-fret fretboard."),
                    ("Cells Mastered", "Cells where your accuracy is 90% or higher with at least 15 attempts. These are notes you consistently identify correctly."),
                    ("Overall Mastery", "A weighted average of your mastery across all cells. Cells with more attempts carry more weight in the calculation.")
                ]
            )
        }
        .sheet(isPresented: $showAccuracyInfo) {
            ProgressInfoSheet(
                title: "Accuracy Trend",
                items: [
                    ("What it shows", "Your daily accuracy (correct answers ÷ total attempts) over the last 30 days of practice."),
                    ("How it's calculated", "All completed sessions on the same day are combined. The chart shows one data point per day you practiced.")
                ]
            )
        }
        .sheet(isPresented: $showResponseTimeInfo) {
            ProgressInfoSheet(
                title: "Avg Response Time",
                items: [
                    ("What it shows", "Your average time to answer correctly in timed quiz sessions, tracked over the last 30 days."),
                    ("How it's calculated", "Only correct answers from timed sessions are included. Incorrect answers and timeouts are excluded. A lower time means faster note recognition.")
                ]
            )
        }
        .sheet(isPresented: $showSessionsInfo) {
            ProgressInfoSheet(
                title: "Recent Sessions",
                items: [
                    ("What it shows", "Your most recent 50 practice sessions with focus mode, date, duration, and accuracy."),
                    ("Filtering", "Use the Filter button to show only specific session types. When a filter is active, the charts and heatmap above also update to reflect only the filtered sessions."),
                    ("Session detail", "Tap any session row to see detailed stats and a fretboard heatmap for that session.")
                ]
            )
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

    // MARK: - Empty / Error States

    private var dataLoadErrorState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.7))
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Could not load progress")
                    .font(DesignSystem.Typography.screenTitle)
                Text("Something went wrong loading your data. Pull down to try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

    private var progressEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "guitars")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.cherry.opacity(0.35))
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No progress yet")
                    .font(DesignSystem.Typography.screenTitle)
                Text("Complete your first session to start tracking your fretboard mastery.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                NotificationCenter.default.post(name: .showPracticeTab, object: nil)
            } label: {
                Text("Start Practicing")
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(DesignSystem.Colors.cherry,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

    private var streakFilterRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(vm.currentStreak)")
                    .font(.headline.weight(.bold).monospacedDigit())
                Text(vm.currentStreak == 1 ? "day streak" : "day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            filterMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var filterMenu: some View {
        Menu {
            Button {
                vm.focusModeFilter = nil
                vm.gameModeFilter = nil
            } label: {
                Label("All Sessions", systemImage: !vm.isAnyFilterActive ? "checkmark" : "")
            }
            Divider()
            ForEach(FocusMode.allCases, id: \.self) { mode in
                Button {
                    vm.gameModeFilter = nil
                    vm.focusModeFilter = mode
                } label: {
                    Label(mode.localizedLabel, systemImage: vm.focusModeFilter == mode ? "checkmark" : "")
                }
            }
            Divider()
            Button {
                vm.focusModeFilter = nil
                vm.gameModeFilter = .timed
            } label: {
                Label("Timed Sessions", systemImage: vm.gameModeFilter == .timed ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.isAnyFilterActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                Text(activeFilterLabel)
            }
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.cherry)
        }
    }

    private var filteredEmptyState: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.tertiary)
            Text("No \(vm.focusModeFilter?.localizedLabel ?? vm.gameModeFilter?.localizedLabel ?? "") sessions recorded")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var sessionEmptyState: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.tertiary)
            Text("No sessions recorded yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Accuracy Trend Chart

    private var accuracyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("ACCURACY TREND")
                infoButton { showAccuracyInfo = true }
            }

            Chart(vm.accuracyTrend) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(DesignSystem.Colors.cherry)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.cherry.opacity(0.3), DesignSystem.Colors.cherry.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.accuracy)
                )
                .foregroundStyle(DesignSystem.Colors.cherry)
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

    // MARK: - Response Time Trend Chart

    private var responseTimeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("AVG RESPONSE TIME (TIMED SESSIONS ONLY)")
                infoButton { showResponseTimeInfo = true }
            }

            Chart(vm.responseTimeTrend) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Time", point.avgTimeMs / 1000.0)
                )
                .foregroundStyle(.cyan)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Time", point.avgTimeMs / 1000.0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Time", point.avgTimeMs / 1000.0)
                )
                .foregroundStyle(.cyan)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.1fs", v))
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, vm.responseTimeTrend.count / 5))) { _ in
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("OVERALL RESULTS")
                infoButton { showOverallInfo = true }
            }

            HStack(spacing: 20) {
                OverallMasteryRing(value: vm.overallMastery)
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    summaryRow(icon: "square.grid.3x3.fill",
                               label: "Cells Attempted",
                               value: "\(vm.attemptedCells) / \(totalCells)",
                               color: DesignSystem.Colors.cherry)
                    summaryRow(icon: "checkmark.seal.fill",
                               label: "Cells Mastered",
                               value: "\(vm.masteredCells)",
                               color: .green)
                    summaryRow(icon: "chart.line.uptrend.xyaxis",
                               label: "Overall Mastery",
                               value: "\(Int(vm.overallMastery * 100))%",
                               color: masteryColor(vm.overallMastery))
                }
                Spacer(minLength: 0)
            }
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
            .font(DesignSystem.Typography.smallLabel)
            .foregroundStyle(.secondary)
    }

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
                    if session.gameMode == .timed {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
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
            .background(DesignSystem.Colors.background)
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

// MARK: - ProgressInfoSheet

private struct ProgressInfoSheet: View {

    let title: String
    let items: [(String, String)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.0) { label, description in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(title)
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
