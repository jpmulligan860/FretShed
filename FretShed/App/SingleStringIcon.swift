// SingleStringIcon.swift
// FretShed — App Layer
//
// Custom icon: 6 horizontal lines (guitar strings) with one highlighted.
// Used as the focus mode icon for "Single String" practice mode.

import SwiftUI

struct SingleStringIcon: View {

    /// Which string to highlight (1 = high E at top, 6 = low E at bottom).
    var highlightedString: Int = 3

    /// Overall frame size.
    var size: CGFloat = 24

    /// Color for the highlighted string.
    var accentColor: Color = DesignSystem.Colors.cherry

    var body: some View {
        Canvas { context, canvasSize in
            let lineWidth: CGFloat = max(1.5, size * 0.1)
            let inset: CGFloat = lineWidth / 2
            let usableHeight = canvasSize.height - lineWidth
            let spacing = usableHeight / 5 // 5 gaps between 6 lines

            for i in 0..<6 {
                let y = inset + CGFloat(i) * spacing
                let isHighlighted = (i + 1) == highlightedString

                var path = Path()
                path.move(to: CGPoint(x: inset, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width - inset, y: y))

                context.stroke(
                    path,
                    with: .color(isHighlighted
                        ? accentColor
                        : DesignSystem.Colors.text2),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Single String Icons") {
    HStack(spacing: 20) {
        SingleStringIcon(highlightedString: 1, size: 24)
        SingleStringIcon(highlightedString: 3, size: 24)
        SingleStringIcon(highlightedString: 6, size: 24)
        SingleStringIcon(highlightedString: 3, size: 44)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
