// SessionHeatmapView.swift
// FretShed — Presentation Layer
//
// Fretboard-style heatmap visualizing a single session's attempt data.
// Columns = frets (0…N from settings), rows = strings 1-6.
// Each cell shows the note name and is colored by result.

import SwiftUI

// MARK: - SessionHeatmapView

struct SessionHeatmapView: View {

    let attempts: [Attempt]
    let fretboardMap: FretboardMap

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat

    @AppStorage(LocalUserPreferences.Key.defaultFretCount)
    private var defaultFretCount: Int = LocalUserPreferences.Default.defaultFretCount

    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    /// Available content width, passed from the parent to avoid self-sizing
    /// feedback loops (onGeometryChange caused infinite layout cycles on iOS 26).
    var availableWidth: CGFloat = 350

    private let stringLabels: [Int: String] = [
        1: "e", 2: "B", 3: "G", 4: "D", 5: "A", 6: "E"
    ]
    private let strings: [Int] = [1, 2, 3, 4, 5, 6]

    private var fretRange: ClosedRange<Int> {
        0...max(defaultFretCount, 5)
    }

    private var cellSize: CGFloat {
        let labelCol: CGFloat = 22
        let spacing: CGFloat = 2
        let count = CGFloat(fretRange.count)
        let inner = availableWidth - 24  // subtract 12pt padding × 2
        return max(10, (inner - labelCol - (count - 1) * spacing) / count)
    }

    /// Per-position results keyed by (string, fret).
    private var grid: [Int: [Int: CellResult]] {
        var result: [Int: [Int: CellResult]] = [:]
        for attempt in attempts {
            let s = attempt.targetString
            let f = attempt.targetFret
            var cell = result[s, default: [:]][f, default: CellResult()]
            if attempt.wasCorrect {
                cell.correct += 1
            } else {
                cell.wrong += 1
            }
            result[s, default: [:]][f] = cell
        }
        return result
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
                        let cell = grid[string]?[fret]
                        let note = fretboardMap.note(string: string, fret: fret)
                        SessionHeatCell(
                            result: cell,
                            maxCount: maxAttemptCount,
                            noteName: note?.displayName(format: noteFormat)
                        )
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }

            // Legend
            SessionHeatmapLegend()
                .padding(.top, 8)
        }
        .padding(12)
        .background(DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
    }

    private var maxAttemptCount: Int {
        var maxCount = 1
        for (_, frets) in grid {
            for (_, cell) in frets {
                maxCount = max(maxCount, cell.total)
            }
        }
        return maxCount
    }
}

// MARK: - CellResult

private struct CellResult {
    var correct: Int = 0
    var wrong: Int = 0
    var total: Int { correct + wrong }
}

// MARK: - SessionHeatCell

private struct SessionHeatCell: View {

    let result: CellResult?
    let maxCount: Int
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
    }

    private var textColor: Color {
        guard let r = result, r.total > 0 else {
            return DesignSystem.Colors.muted.opacity(0.5)
        }
        return .white
    }

    private var cellColor: Color {
        guard let r = result, r.total > 0 else {
            return DesignSystem.Colors.surface2
        }
        let opacity = 0.35 + 0.65 * (Double(r.total) / Double(max(maxCount, 1)))
        if r.wrong == 0 {
            return DesignSystem.Colors.correct.opacity(opacity)
        } else if r.correct == 0 {
            return DesignSystem.Colors.wrong.opacity(opacity)
        } else {
            return DesignSystem.Colors.amber.opacity(opacity)
        }
    }
}

// MARK: - SessionHeatmapLegend

struct SessionHeatmapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendItem(color: DesignSystem.Colors.surface2, label: "Not asked")
            legendItem(color: DesignSystem.Colors.correct.opacity(0.65), label: "Correct")
            legendItem(color: DesignSystem.Colors.wrong.opacity(0.65),   label: "Wrong")
            legendItem(color: DesignSystem.Colors.amber.opacity(0.65),   label: "Mixed")
        }
        .font(.system(size: 10))
        .foregroundStyle(DesignSystem.Colors.text2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
        }
    }
}
