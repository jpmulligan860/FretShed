// FretboardView.swift
// FretShed — Presentation Layer
//
// Height is derived from a fixed string spacing so the board always looks
// proportional regardless of the number of visible frets.

import SwiftUI

// MARK: - CompactFretboardView

public struct CompactFretboardView: View {

    public let targetQuestion: QuizQuestion?
    public let revealAllPositions: Bool
    public let fretboardMap: FretboardMap
    public let noteFormat: NoteNameFormat
    public let isLeftHanded: Bool
    public var showNoteNames: Bool = true
    public var showTargetDot: Bool = true
    public var fretRange: ClosedRange<Int> = 0...12
    /// When set, fret spacing is computed to fill this width exactly.
    public var availableWidth: CGFloat? = nil

    private let stringSpacing: CGFloat = 22
    private let maxDotRadius: CGFloat = 11
    private let nutWidth: CGFloat = 5
    private let stringCount = 6

    private var visibleFrets: Int { fretRange.upperBound - fretRange.lowerBound + 1 }
    // openStringMargin uses the maximum dot radius so the open-string column
    // is always wide enough regardless of how many frets are visible.
    private var openStringMargin: CGFloat { maxDotRadius * 2 + 6 }

    /// Fret spacing — either computed to fill `availableWidth` or a fixed default.
    private var fretSpacing: CGFloat {
        if let w = availableWidth {
            let fixedPortion = openStringMargin + nutWidth
            return max(8, (w - fixedPortion) / CGFloat(visibleFrets))
        }
        return 32
    }

    /// Dot radius scales down proportionally when frets are tightly packed,
    /// so dots never overlap at high fret counts (22/24-fret guitars).
    private var dotRadius: CGFloat { min(maxDotRadius, fretSpacing * 0.42) }

    private var boardWidth: CGFloat { openStringMargin + nutWidth + fretSpacing * CGFloat(visibleFrets) }
    private var boardHeight: CGFloat { stringSpacing * CGFloat(stringCount + 1) }

    public var naturalWidth: CGFloat { boardWidth }
    public var naturalHeight: CGFloat { boardHeight }

    private static let singleDots: Set<Int> = [3, 5, 7, 9]
    private static let doubleDots: Set<Int> = [12, 24]

    public var body: some View {
        Canvas { ctx, size in
            drawBoard(ctx: ctx, size: size)
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
    }

    private func drawBoard(ctx: GraphicsContext, size: CGSize) {
        let nutX = openStringMargin
        let topPad = stringSpacing

        // Background
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(DesignSystem.Colors.fretboardWood)
        )

        // Nut
        ctx.fill(
            Path(CGRect(x: nutX, y: 0, width: nutWidth, height: size.height)),
            with: .color(.white)
        )

        // Fret wires
        for i in 0...visibleFrets {
            let x = nutX + nutWidth + CGFloat(i) * fretSpacing
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(p, with: .color(.gray.opacity(0.45)), lineWidth: 1.5)
        }

        // Strings — string 1 (high e, thinnest) drawn at top, string 6 (low E) at bottom.
        // thicknesses[0] = string 1, thicknesses[5] = string 6.
        let thicknesses: [CGFloat] = [0.8, 1.1, 1.5, 1.9, 2.3, 2.8]
        for s in 0..<stringCount {
            let y = topPad + CGFloat(s) * stringSpacing
            var p = Path()
            p.move(to: CGPoint(x: nutX, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p,
                       with: .color(DesignSystem.Colors.fretboardStrings),
                       lineWidth: thicknesses[s])
        }

        // Position markers
        let midY = size.height / 2
        for fret in fretRange where fret > 0 {
            let visIdx = fret - fretRange.lowerBound
            let x = nutX + nutWidth + (CGFloat(visIdx) - 0.5) * fretSpacing
            if Self.doubleDots.contains(fret) {
                markerDot(ctx: ctx, at: CGPoint(x: x, y: midY - stringSpacing * 0.7))
                markerDot(ctx: ctx, at: CGPoint(x: x, y: midY + stringSpacing * 0.7))
            } else if Self.singleDots.contains(fret) {
                markerDot(ctx: ctx, at: CGPoint(x: x, y: midY))
            }
        }

        // Note dots — visual row 0 (top) = string 1 (high e).
        // Left-handed layout flips which string number appears at each row,
        // but string 1 remains at the top of the display.
        for s in 0..<stringCount {
            let displayString = isLeftHanded ? (stringCount - s) : (s + 1)
            let y = topPad + CGFloat(s) * stringSpacing

            for fret in fretRange {
                guard let note = fretboardMap.note(string: displayString, fret: fret) else { continue }
                let visIdx = fret - fretRange.lowerBound
                let x: CGFloat = fret == 0
                    ? nutX - dotRadius - 2                                       // centred in open-string margin
                    : nutX + nutWidth + (CGFloat(visIdx) - 0.5) * fretSpacing

                let isTarget = showTargetDot
                    && targetQuestion?.note == note
                    && targetQuestion?.string == displayString
                    && targetQuestion?.fret == fret
                let isReveal = revealAllPositions && targetQuestion?.note == note

                if isTarget {
                    noteDot(ctx: ctx, at: CGPoint(x: x, y: y),
                            note: note, fill: .orange, format: noteFormat)
                } else if isReveal {
                    noteDot(ctx: ctx, at: CGPoint(x: x, y: y),
                            note: note, fill: .green.opacity(0.85), format: noteFormat)
                }
            }
        }
    }

    private func markerDot(ctx: GraphicsContext, at pt: CGPoint) {
        let r: CGFloat = 3
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)),
                 with: .color(.white.opacity(0.2)))
    }

    private func noteDot(ctx: GraphicsContext, at pt: CGPoint,
                         note: MusicalNote, fill: Color, format: NoteNameFormat) {
        let r = dotRadius
        ctx.fill(Path(ellipseIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)),
                 with: .color(fill))
        if showNoteNames {
            let label = ctx.resolve(
                Text(note.displayName(format: format))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            )
            ctx.draw(label, at: pt)
        }
    }
}

// MARK: - FretboardView (alias)

public struct FretboardView: View {
    public let targetQuestion: QuizQuestion?
    public let revealAllPositions: Bool
    public let fretboardMap: FretboardMap
    public let noteFormat: NoteNameFormat
    public let isLeftHanded: Bool
    public var showNoteNames: Bool = true
    public var showTargetDot: Bool = true
    public var fretRange: ClosedRange<Int> = 0...12

    public var body: some View {
        CompactFretboardView(
            targetQuestion: targetQuestion,
            revealAllPositions: revealAllPositions,
            fretboardMap: fretboardMap,
            noteFormat: noteFormat,
            isLeftHanded: isLeftHanded,
            showNoteNames: showNoteNames,
            showTargetDot: showTargetDot,
            fretRange: fretRange
        )
    }
}
