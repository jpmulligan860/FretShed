// MasteryHeatmapView.swift
// FretShed — Presentation Layer (Phase 4)
//
// 6-row × 12-column grid showing per-cell mastery colour.
// Rows = guitar strings (1 = high-e at top, 6 = low-E at bottom).
// Columns = the 12 chromatic notes in pitch-class order (C … B).

import SwiftUI

// MARK: - MasteryHeatmapView

struct MasteryHeatmapView: View {

    let vm: ProgressViewModel

    @AppStorage(LocalUserPreferences.Key.noteNameFormat)
    private var noteFormatRaw: String = LocalUserPreferences.Default.noteNameFormat

    private var noteFormat: NoteNameFormat {
        NoteNameFormat(rawValue: noteFormatRaw) ?? .sharps
    }

    /// Notes displayed left-to-right (C = 0 … B = 11).
    private let notes: [MusicalNote] = MusicalNote.allCases.sorted { $0.rawValue < $1.rawValue }
    /// Strings displayed top-to-bottom (1 = high-e … 6 = low-E).
    private let strings: [Int] = [1, 2, 3, 4, 5, 6]

    private let stringLabels: [Int: String] = [
        1: "e", 2: "B", 3: "G", 4: "D", 5: "A", 6: "E"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Column headers (note names) ──────────────────────────
            HStack(spacing: 2) {
                // Offset for the row-label column
                Text("").frame(width: 22)
                ForEach(notes) { note in
                    Text(note.displayName(format: noteFormat))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 3)

            // ── Grid rows ────────────────────────────────────────────
            ForEach(strings, id: \.self) { string in
                HStack(spacing: 2) {
                    // Row label (string name)
                    Text(stringLabels[string] ?? "")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .center)

                    ForEach(notes) { note in
                        HeatCell(
                            score: vm.masteryScore(note: note, string: string),
                            level: vm.masteryLevel(note: note, string: string),
                            isAttempted: vm.scoreGrid[string][note.rawValue] != nil
                        )
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            Task { await vm.selectCell(note: note, string: string) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - HeatCell

private struct HeatCell: View {

    let score: Double
    let level: MasteryLevel
    let isAttempted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        level == .mastered ? Color.green.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }

    private var cellColor: Color {
        guard isAttempted else {
            return Color(.tertiarySystemGroupedBackground)
        }
        switch level {
        case .mastered:   return Color.green.opacity(lerp(0.55, 1.0, score, in: 0.9...1.0))
        case .proficient: return Color.blue.opacity(lerp(0.35, 0.65, score, in: 0.7...0.9))
        case .developing: return Color.orange.opacity(lerp(0.3, 0.55, score, in: 0.4...0.7))
        case .beginner:   return Color.red.opacity(lerp(0.2, 0.45, score, in: 0.0...0.4))
        }
    }

    /// Linear interpolation mapping `value` within `range` to the output interval [lo, hi].
    private func lerp(_ lo: Double, _ hi: Double, _ value: Double, in range: ClosedRange<Double>) -> Double {
        let t = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return lo + (hi - lo) * min(max(t, 0), 1)
    }
}

// MARK: - Legend

struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendItem(color: Color(.tertiarySystemGroupedBackground), label: "Not tried")
            legendItem(color: .red.opacity(0.35),    label: "Beginner")
            legendItem(color: .orange.opacity(0.45), label: "Developing")
            legendItem(color: .blue.opacity(0.55),   label: "Proficient")
            legendItem(color: .green.opacity(0.85),  label: "Mastered")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
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
