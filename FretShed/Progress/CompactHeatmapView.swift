// CompactHeatmapView.swift
// FretShed — Progress Layer
//
// Lightweight mastery heatmap for the Shed page.
// Shows the full 6×13 fretboard grid with small cells,
// string labels, and a simplified 3-label legend.

import SwiftUI

struct CompactHeatmapView: View {

    let masteryRepository: any MasteryRepository
    let fretboardMap: FretboardMap

    @State private var scores: [MasteryScore] = []

    private let strings: [Int] = [1, 2, 3, 4, 5, 6]
    private let stringLabels: [Int: String] = [
        1: "e", 2: "B", 3: "G", 4: "D", 5: "A", 6: "E"
    ]
    private let fretRange = 0...12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Grid rows
            ForEach(strings, id: \.self) { string in
                HStack(spacing: 1.5) {
                    Text(stringLabels[string] ?? "")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.text2)
                        .frame(width: 14, alignment: .center)

                    ForEach(Array(fretRange), id: \.self) { fret in
                        compactCell(string: string, fret: fret)
                    }
                }
            }

            // Legend
            HStack(spacing: DesignSystem.Spacing.md) {
                Spacer()
                legendDot(color: DesignSystem.Colors.heatmapStruggling, label: "Weak")
                legendDot(color: DesignSystem.Colors.heatmapLearning, label: "Learning")
                legendDot(color: DesignSystem.Colors.heatmapProficient, label: "Strong")
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .task { loadScores() }
    }

    @ViewBuilder
    private func compactCell(string: Int, fret: Int) -> some View {
        let note = fretboardMap.note(string: string, fret: fret)
        let scoreObj = note.flatMap { n in
            scores.first(where: { $0.noteRaw == n.rawValue && $0.stringNumber == string })
        }
        let hasData = scoreObj != nil
        let score = scoreObj?.score ?? 0.0
        let isMastered = scoreObj?.isMastered ?? false

        RoundedRectangle(cornerRadius: 2)
            .fill(hasData ? cellColor(score: score, isMastered: isMastered) : DesignSystem.Colors.surface2)
            .frame(height: 10)
            .frame(maxWidth: .infinity)
    }

    private func cellColor(score: Double, isMastered: Bool) -> Color {
        switch score {
        case ..<0.50:  return DesignSystem.Colors.heatmapStruggling
        case ..<0.75:  return DesignSystem.Colors.heatmapLearning
        default:       return isMastered ? DesignSystem.Colors.heatmapMastered : DesignSystem.Colors.heatmapProficient
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.muted)
        }
    }

    private func loadScores() {
        scores = (try? masteryRepository.allScores()) ?? []
    }
}
