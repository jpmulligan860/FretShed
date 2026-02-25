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
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize)
                }
            }
            .padding(.bottom, 3)

            // Grid rows
            ForEach(strings, id: \.self) { string in
                HStack(spacing: 2) {
                    Text(stringLabels[string] ?? "")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .center)

                    ForEach(Array(fretRange), id: \.self) { fret in
                        let note = fretboardMap.note(string: string, fret: fret)
                        let score = note.map { vm.masteryScore(note: $0, string: string) } ?? 0
                        let level = note.map { vm.masteryLevel(note: $0, string: string) } ?? .beginner
                        let attempted = note.map { vm.scoreGrid[string][$0.rawValue] != nil } ?? false
                        HeatCell(
                            score: score,
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

    let score: Double
    let level: MasteryLevel
    let isAttempted: Bool
    let noteName: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            level == .mastered && isAttempted ? DesignSystem.Colors.correct.opacity(0.6) : Color.clear,
                            lineWidth: 1.5
                        )
                )
            if let name = noteName {
                Text(name)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(isAttempted ? .white : .secondary.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var cellColor: Color {
        guard isAttempted else {
            return DesignSystem.Colors.surface2
        }
        switch level {
        case .mastered:   return DesignSystem.Colors.correct.opacity(lerp(0.55, 1.0, score, in: 0.9...1.0))
        case .proficient: return DesignSystem.Colors.gold.opacity(lerp(0.35, 0.65, score, in: 0.7...0.9))
        case .developing: return DesignSystem.Colors.amber.opacity(lerp(0.3, 0.55, score, in: 0.4...0.7))
        case .beginner:   return DesignSystem.Colors.cherry.opacity(lerp(0.2, 0.45, score, in: 0.0...0.4))
        }
    }

    private func lerp(_ lo: Double, _ hi: Double, _ value: Double,
                      in range: ClosedRange<Double>) -> Double {
        let t = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return lo + (hi - lo) * min(max(t, 0), 1)
    }
}

// MARK: - HeatmapLegend

struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            legendItem(color: DesignSystem.Colors.surface2, label: "Untried")
            legendItem(color: DesignSystem.Colors.cherry.opacity(0.35),  label: "Beginner")
            legendItem(color: DesignSystem.Colors.amber.opacity(0.45),   label: "Developing")
            legendItem(color: DesignSystem.Colors.gold.opacity(0.55),    label: "Proficient")
            legendItem(color: DesignSystem.Colors.correct.opacity(0.85), label: "Mastered")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}
