// MasteryHeatmapView.swift
// FretShed — Presentation Layer (Phase 4)
//
// Fretboard-style mastery heatmap. Columns = frets (0…N from settings),
// rows = strings 1-6. Each cell shows the note name and is colored by mastery level.
//
// The parent view passes `availableWidth` so that cell sizing is computed from
// the parent's geometry — no self-sizing feedback loop that could cause an
// infinite layout cycle on iOS 26.

import SwiftUI

// MARK: - MasteryHeatmapView

struct MasteryHeatmapView: View {

    let vm: ProgressViewModel
    let fretboardMap: FretboardMap
    /// Available content width, passed from the parent to avoid self-sizing
    /// feedback loops (the onGeometryChange pattern caused infinite layout
    /// cycles on iOS 26).
    var availableWidth: CGFloat = 350

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat

    @AppStorage(LocalUserPreferences.Key.defaultFretCount)
    private var defaultFretCount: Int = LocalUserPreferences.Default.defaultFretCount

    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    private let strings: [Int] = [1, 2, 3, 4, 5, 6]
    private let stringLabels: [Int: String] = [
        1: "e", 2: "B", 3: "G", 4: "D", 5: "A", 6: "E"
    ]
    private var fretRange: ClosedRange<Int> {
        0...max(defaultFretCount, 5)
    }

    /// Cell size computed from the parent-provided available width.
    private var cellSize: CGFloat {
        let labelCol: CGFloat = 22
        let spacing: CGFloat = 2
        let count = CGFloat(fretRange.count)
        // Subtract internal padding (12pt × 2 = 24pt) from the available width.
        let inner = availableWidth - 24
        return max(10, (inner - labelCol - (count - 1) * spacing) / count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fret number header
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 22)
                ForEach(Array(fretRange), id: \.self) { fret in
                    Text("\(fret)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .frame(width: cellSize)
                }
            }
            .padding(.bottom, 3)

            // Grid rows
            ForEach(strings, id: \.self) { string in
                HStack(spacing: 2) {
                    Text(stringLabels[string] ?? "")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .frame(width: 22, alignment: .center)

                    ForEach(Array(fretRange), id: \.self) { fret in
                        let note = fretboardMap.note(string: string, fret: fret)
                        let scoreObj = note.flatMap { vm.scoreGrid[string][$0.rawValue] }
                        let level = note.map { vm.masteryLevel(note: $0, string: string) } ?? .struggling
                        let attempted = scoreObj != nil
                        HeatCell(
                            level: level,
                            isAttempted: attempted,
                            noteName: note?.displayName(format: noteFormat)
                        )
                        .frame(width: cellSize, height: cellSize)
                        .onTapGesture {
                            if let note {
                                Task { await vm.selectCell(note: note, string: string) }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }
}

// MARK: - HeatCell

private struct HeatCell: View {

    @Environment(\.colorScheme) private var colorScheme

    let level: MasteryLevel
    let isAttempted: Bool
    let noteName: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellColor)
            if let name = noteName {
                Text(name)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .shadow(color: glowColor, radius: colorScheme == .dark && isAttempted ? 3 : 0)
    }

    private var cellColor: Color {
        guard isAttempted else {
            return DesignSystem.Colors.surface2
        }
        switch level {
        case .struggling, .beginner:
            return DesignSystem.Colors.heatmapStruggling
        case .learning, .developing:
            return DesignSystem.Colors.heatmapLearning
        case .proficient:
            return DesignSystem.Colors.heatmapProficient
        case .mastered:
            return DesignSystem.Colors.heatmapMastered
        }
    }

    private var textColor: Color {
        guard isAttempted else {
            return DesignSystem.Colors.muted.opacity(0.5)
        }
        // Dark text on bright gold for readability
        if level == .mastered { return Color(white: 0.15) }
        return .white
    }

    private var glowColor: Color {
        guard isAttempted else { return .clear }
        switch level {
        case .struggling, .beginner:
            return DesignSystem.Colors.heatmapStrugglingGlow.opacity(0.5)
        case .learning, .developing:
            return DesignSystem.Colors.heatmapLearningGlow.opacity(0.5)
        case .proficient:
            return DesignSystem.Colors.heatmapProficientGlow.opacity(0.5)
        case .mastered:
            return DesignSystem.Colors.heatmapMasteredGlow.opacity(0.7)
        }
    }
}

// MARK: - HeatmapLegend

struct HeatmapLegend: View {

    let vm: ProgressViewModel
    let fretboardMap: FretboardMap
    let fretCount: Int

    private var tierCounts: (untried: Int, struggling: Int, learning: Int, proficient: Int, mastered: Int) {
        var untried = 0, struggling = 0, learning = 0, proficient = 0, mastered = 0
        for string in 1...6 {
            for fret in 0...fretCount {
                guard let note = fretboardMap.note(string: string, fret: fret) else { continue }
                let score = vm.scoreGrid[string][note.rawValue]
                guard score != nil else { untried += 1; continue }
                let level = vm.masteryLevel(note: note, string: string)
                switch level {
                case .struggling, .beginner:   struggling += 1
                case .learning, .developing:   learning += 1
                case .proficient:              proficient += 1
                case .mastered:                mastered += 1
                }
            }
        }
        return (untried, struggling, learning, proficient, mastered)
    }

    var body: some View {
        let counts = tierCounts
        HStack(spacing: 5) {
            legendItem(color: DesignSystem.Colors.surface2,           label: "Untried", count: counts.untried)
            legendItem(color: DesignSystem.Colors.heatmapStruggling,  label: "Struggling", count: counts.struggling)
            legendItem(color: DesignSystem.Colors.heatmapLearning,    label: "Learning", count: counts.learning)
            legendItem(color: DesignSystem.Colors.heatmapProficient,  label: "Proficient", count: counts.proficient)
            legendItem(color: DesignSystem.Colors.heatmapMastered,    label: "Mastered", count: counts.mastered)
        }
        .font(.system(size: 9))
        .foregroundStyle(DesignSystem.Colors.text2)
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text("\(label) (\(count))")
        }
    }
}
