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

    private var totalTimePracticedLabel: String {
        let total = vm.filteredSessions.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let mins  = (Int(total) % 3600) / 60
        let secs  = Int(total) % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    private var activeFilterLabel: String {
        if vm.todayFilter {
            return "Filtered: Today"
        }
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
                                            availableWidth: (geo.size.width - 48) / 2 - 32
                                        )
                                        HeatmapLegend(vm: vm, fretboardMap: container.fretboardMap, fretCount: defaultFretCount)
                                            .padding(.horizontal, 4)
                                    }
                                    .padding(16)
                                    .background(DesignSystem.Colors.surface,
                                                in: RoundedRectangle(cornerRadius: 18))
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                                PhaseRoadmapSection(
                                    phaseManager: LearningPhaseManager(),
                                    sessionAccuracy: vm.overallMastery
                                )
                                .padding(.horizontal, 16)

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
                                // Order: Streak/Filter → Overall → Phase Roadmap → Fretboard Mastery → Accuracy Trend → Avg Response Time
                                streakFilterRow

                                overallCard
                                    .padding(.horizontal, 16)

                                PhaseRoadmapSection(
                                    phaseManager: LearningPhaseManager(),
                                    sessionAccuracy: vm.overallMastery
                                )
                                .padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 8) {
                                    masterySectionHeader
                                    MasteryHeatmapView(
                                        vm: vm,
                                        fretboardMap: container.fretboardMap,
                                        availableWidth: geo.size.width - 64
                                    )
                                    HeatmapLegend(vm: vm, fretboardMap: container.fretboardMap, fretCount: defaultFretCount)
                                        .padding(.horizontal, 4)
                                }
                                .padding(16)
                                .background(DesignSystem.Colors.surface,
                                            in: RoundedRectangle(cornerRadius: 18))
                                .padding(.horizontal, 16)

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
                                if vm.filteredSessions.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            sectionHeader("RECENT SESSIONS")
                                            infoButton { showSessionsInfo = true }
                                            Spacer()
                                            filterMenu
                                        }
                                        if vm.isAnyFilterActive {
                                            filteredEmptyState
                                                .padding(.horizontal, 0)
                                        } else {
                                            sessionEmptyState
                                                .padding(.horizontal, 0)
                                        }
                                    }
                                    .padding(16)
                                    .background(DesignSystem.Colors.surface,
                                                in: RoundedRectangle(cornerRadius: 18))
                                    .padding(.horizontal, 16)
                                } else {
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack {
                                            sectionHeader("RECENT SESSIONS")
                                            infoButton { showSessionsInfo = true }
                                            Spacer()
                                            filterMenu
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)

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
                                        DesignSystem.Colors.surface,
                                        in: RoundedRectangle(cornerRadius: 18)
                                    )
                                    .padding(.horizontal, 16)
                                }

                                if !vm.recentSessions.isEmpty {
                                    Button(role: .destructive) {
                                        showDeleteAllConfirm = true
                                    } label: {
                                        Text("Delete All Sessions")
                                            .font(DesignSystem.Typography.smallLabel)
                                            .foregroundStyle(DesignSystem.Colors.wrong)
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
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .onAppear { Task { await vm.load() } }
        .sheet(item: $vm.selectedCell) { detail in
            CellDetailSheet(detail: detail)
        }
        .sheet(item: $vm.selectedSession) { detail in
            SessionDetailView(detail: detail) {
                Task { await vm.deleteSession(detail.session) }
            }
        }
        .sheet(isPresented: $showMasteryInfo) {
            MasteryInfoSheet()
        }
        .sheet(isPresented: $showOverallInfo) {
            ProgressInfoSheet(
                title: "Overall Results",
                items: [
                    ("Cells Attempted", "The number of unique note+string positions you have practiced out of \(totalCells) total cells on your \(defaultFretCount)-fret fretboard."),
                    ("Time Practiced", "The total time spent across all sessions. When a filter is active, this reflects only the filtered sessions."),
                    ("Cells Mastered", "Notes you've identified correctly across multiple sessions over several days. Mastered means proven long-term recall, not just a good session."),
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
                    ("What it shows", "Your average time to answer correctly, tracked over the last 30 days of practice."),
                    ("How it's calculated", "Only correct answers are counted — a lower time means faster recognition.")
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
            Text("\"Delete Sessions Only\" removes your history and resets the heatmap. \"Delete Sessions & Reset Mastery\" performs a full wipe of all data. Neither action can be undone.")
        }
    }

    // MARK: - Empty / Error States

    private var dataLoadErrorState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52))
                .foregroundStyle(DesignSystem.Colors.amber.opacity(0.7))
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Could not load progress")
                    .font(DesignSystem.Typography.screenTitle)
                Text("Something went wrong loading your data. Pull down to try again.")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
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
                Text("Play your first session to start tracking your progress.")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                NotificationCenter.default.post(name: .showPracticeTab, object: nil)
            } label: {
                Text("Start Practicing")
                    .font(DesignSystem.Typography.sectionHeader)
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
                    .foregroundStyle(DesignSystem.Colors.amber)
                Text("\(vm.currentStreak)")
                    .font(DesignSystem.Typography.sectionHeader)
                    .monospacedDigit()
                Text(vm.currentStreak == 1 ? "day" : "day streak")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
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
                vm.todayFilter = false
                vm.focusModeFilter = nil
                vm.gameModeFilter = nil
            } label: {
                Label("All Sessions", systemImage: !vm.isAnyFilterActive ? "checkmark" : "")
            }
            Button {
                vm.focusModeFilter = nil
                vm.gameModeFilter = nil
                vm.todayFilter = true
            } label: {
                Label("Today's Sessions", systemImage: vm.todayFilter ? "checkmark" : "")
            }
            Divider()
            ForEach(FocusMode.activeCases, id: \.self) { mode in
                Button {
                    vm.todayFilter = false
                    vm.gameModeFilter = nil
                    vm.focusModeFilter = mode
                } label: {
                    Label(mode.localizedLabel, systemImage: vm.focusModeFilter == mode ? "checkmark" : "")
                }
            }
            Divider()
            Button {
                vm.todayFilter = false
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
            .font(DesignSystem.Typography.bodyLabel)
            .foregroundStyle(DesignSystem.Colors.cherry)
        }
    }

    private var filteredEmptyState: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(DesignSystem.Colors.muted)
            Text(vm.todayFilter
                 ? "No sessions recorded today"
                 : "No \(vm.focusModeFilter?.localizedLabel ?? vm.gameModeFilter?.localizedLabel ?? "") sessions recorded")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionEmptyState: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(DesignSystem.Colors.muted)
            Text("No sessions recorded yet")
                .font(DesignSystem.Typography.bodyLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                                .font(DesignSystem.Typography.microLabel)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, vm.accuracyTrend.count / 4))) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.defaultDigits).day())
                                .font(DesignSystem.Typography.sectionLabel)
                        }
                    }
                }
            }
            .frame(height: 160)
            .padding(.top, 4)
        }
        .padding(16)
        .background(DesignSystem.Colors.surface,
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
                .foregroundStyle(DesignSystem.Colors.amber)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Time", point.avgTimeMs / 1000.0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.amber.opacity(0.3), DesignSystem.Colors.amber.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Time", point.avgTimeMs / 1000.0)
                )
                .foregroundStyle(DesignSystem.Colors.amber)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.1fs", v))
                                .font(DesignSystem.Typography.microLabel)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(4, vm.responseTimeTrend.count / 5))) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.defaultDigits).day())
                                .font(DesignSystem.Typography.sectionLabel)
                        }
                    }
                }
            }
            .frame(height: 160)
            .padding(.top, 4)
        }
        .padding(16)
        .background(DesignSystem.Colors.surface,
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
                    summaryRow(icon: "clock.fill",
                               label: "Time Practiced",
                               value: totalTimePracticedLabel,
                               color: DesignSystem.Colors.amber)
                    summaryRow(icon: "checkmark.seal.fill",
                               label: "Cells Mastered",
                               value: "\(vm.visibleMasteredCells(fretboardMap: container.fretboardMap, fretCount: defaultFretCount))",
                               color: DesignSystem.Colors.masteryMastered)
                    summaryRow(icon: "chart.line.uptrend.xyaxis",
                               label: "Overall Mastery",
                               value: "\(Int(vm.overallMastery * 100))%",
                               color: masteryColor(vm.overallMastery))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryRow(icon: String, label: String,
                            value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.smallLabel)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.smallLabel)
            .foregroundStyle(DesignSystem.Colors.text2)
    }

    private func infoButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
        }
    }

    private var masterySectionHeader: some View {
        HStack {
            sectionHeader("FRETBOARD MASTERY")
            Button {
                showMasteryInfo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }

    private func masteryColor(_ score: Double) -> Color {
        DesignSystem.Colors.masteryColor(for: score)
    }
}

// MARK: - OverallMasteryRing

private struct OverallMasteryRing: View {
    let value: Double

    private var ringColor: Color {
        DesignSystem.Colors.masteryColor(for: value)
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
                    .font(DesignSystem.Typography.mediumTitle)
                    .monospacedDigit()
                Text("%")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
            }
        }
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            sessionIcon
                .frame(width: 36, height: 36)
                .background(modeColor(session.focusMode).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(session.focusMode.localizedLabel)
                        .font(DesignSystem.Typography.bodyLabel)
                    if session.gameMode == .timed {
                        Image(systemName: "clock.fill")
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.amber)
                    }
                    if session.isAdaptive {
                        Image(systemName: "brain")
                            .font(DesignSystem.Typography.smallLabel)
                            .foregroundStyle(DesignSystem.Colors.gold)
                    }
                }
                HStack(spacing: 6) {
                    Text(session.startTime, style: .date)
                    Text("·")
                    Text(durationLabel(session.duration))
                }
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.text2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.accuracyPercent))%")
                    .font(DesignSystem.Typography.bodyLabel)
                    .foregroundStyle(accuracyColor(session.accuracyPercent))
                Text("\(session.correctCount)/\(session.attemptCount)")
                    .font(DesignSystem.Typography.smallLabel)
                    .foregroundStyle(DesignSystem.Colors.text2)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(DesignSystem.Typography.smallLabel)
                .foregroundStyle(DesignSystem.Colors.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var sessionIcon: some View {
        if session.focusMode == .singleString {
            let targetString = session.targetStrings.first ?? 3
            SingleStringIcon(
                highlightedString: targetString,
                size: 20,
                accentColor: modeColor(session.focusMode)
            )
        } else {
            Image(systemName: modeIcon(session.focusMode))
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundStyle(modeColor(session.focusMode))
        }
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    private func modeIcon(_ mode: FocusMode) -> String {
        switch mode {
        case .fullFretboard:       return "rectangle.grid.3x2"
        case .singleNote:          return "music.note"
        case .circleOfFifths:      return "circle.dashed"
        case .circleOfFourths:     return "circle.grid.2x1"
        case .singleString:        return "minus"
        case .chordProgression:    return "pianokeys"
        case .fretboardPosition:   return "slider.horizontal.3"
        case .accuracyAssessment:  return "waveform.badge.magnifyingglass"
        case .naturalNotes:        return "textformat.abc"
        case .sharpsAndFlats:      return "number"
        }
    }

    private func modeColor(_ mode: FocusMode) -> Color {
        switch mode {
        case .fullFretboard:       return DesignSystem.Colors.cherry
        case .singleString:        return DesignSystem.Colors.amber
        case .singleNote:          return DesignSystem.Colors.honey
        case .fretboardPosition:   return DesignSystem.Colors.gold
        case .naturalNotes:        return DesignSystem.Colors.correct
        case .sharpsAndFlats:      return DesignSystem.Colors.cherryLight
        case .accuracyAssessment:  return DesignSystem.Colors.cherry
        case .circleOfFourths:     return DesignSystem.Colors.amber
        case .circleOfFifths:      return DesignSystem.Colors.honey
        case .chordProgression:    return DesignSystem.Colors.gold
        }
    }

    private func accuracyColor(_ pct: Double) -> Color {
        if pct >= 80 { return DesignSystem.Colors.correct }
        if pct >= 60 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.wrong
    }
}

// MARK: - MasteryInfoSheet

private struct MasteryInfoSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let levels: [(String, Color, String, String)] = [
        ("Struggling",  DesignSystem.Colors.masteryStruggling, "0 – 49%",   "This one's still new. The more you see it, the faster it'll click."),
        ("Learning",    DesignSystem.Colors.masteryLearning,   "50 – 74%",  "Getting there! A bit more practice and this note will feel automatic."),
        ("Proficient",  DesignSystem.Colors.masteryProficient, "75%+", "You know this note. Keep coming back over the next few days to lock it in for good."),
        ("Mastered",    DesignSystem.Colors.masteryMastered,   "75%+ · spaced recall", "You've proven you remember this note across multiple sessions over several days. Locked in.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Each cell on the heatmap represents a specific note on a specific string. Colors show four stages: struggling (red), learning (amber), proficient (gold), and mastered (green). A cell turns green when you\u{2019}ve identified it correctly across multiple sessions over several days.")
                        .font(DesignSystem.Typography.bodyLabel)
                        .foregroundStyle(DesignSystem.Colors.text2)

                    ForEach(levels, id: \.0) { name, color, range, desc in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.opacity(0.7))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(name).font(DesignSystem.Typography.bodyLabel)
                                    Spacer()
                                    Text(range)
                                        .font(DesignSystem.Typography.smallLabel)
                                        .foregroundStyle(DesignSystem.Colors.text2)
                                }
                                Text(desc)
                                    .font(DesignSystem.Typography.smallLabel)
                                    .foregroundStyle(DesignSystem.Colors.text2)
                            }
                        }
                    }

                    Text("Tap any cell on the heatmap to see detailed stats and recent attempts for that note.")
                        .font(DesignSystem.Typography.smallLabel)
                        .foregroundStyle(DesignSystem.Colors.muted)
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
                                .font(DesignSystem.Typography.bodyLabel)
                            Text(description)
                                .font(DesignSystem.Typography.smallLabel)
                                .foregroundStyle(DesignSystem.Colors.text2)
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
