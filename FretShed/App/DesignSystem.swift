import SwiftUI
import UIKit

enum DesignSystem {

    // MARK: - Colors — Woodshop Cherry Sunburst Palette (A1)
    enum Colors {
        // Brand primaries
        static let cherry = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.698, green: 0.133, blue: 0.133, alpha: 1)  // #B22222
            : UIColor(red: 0.600, green: 0.100, blue: 0.100, alpha: 1)  // #991A1A
        })
        static let cherryLight = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.800, green: 0.200, blue: 0.200, alpha: 1)  // #CC3333
            : UIColor(red: 0.698, green: 0.133, blue: 0.133, alpha: 1)  // #B22222
        })
        static let amber = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.900, green: 0.420, blue: 0.050, alpha: 1)  // #E66B0D — deep orange
            : UIColor(red: 0.800, green: 0.350, blue: 0.030, alpha: 1)  // #CC5908 — burnt orange
        })
        static let honey = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.900, green: 0.720, blue: 0.250, alpha: 1)  // #E6B840
            : UIColor(red: 0.800, green: 0.620, blue: 0.150, alpha: 1)  // #CC9E26
        })
        static let gold = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.960, green: 0.860, blue: 0.120, alpha: 1)  // #F5DB1F — bright yellow
            : UIColor(red: 0.870, green: 0.770, blue: 0.060, alpha: 1)  // #DEC40F — vivid yellow
        })
        static let cream = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.950, green: 0.920, blue: 0.860, alpha: 1)  // #F2EBDB
            : UIColor(red: 0.980, green: 0.965, blue: 0.930, alpha: 1)  // #FAF7ED
        })
        static let rosewood = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.200, green: 0.120, blue: 0.080, alpha: 1)  // #331F14
            : UIColor(red: 0.280, green: 0.180, blue: 0.120, alpha: 1)  // #472E1F
        })
        static let woodMed = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.300, green: 0.220, blue: 0.160, alpha: 1)  // #4D3829
            : UIColor(red: 0.420, green: 0.320, blue: 0.230, alpha: 1)  // #6B523B
        })
        static let woodLight = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.400, green: 0.320, blue: 0.240, alpha: 1)  // #66523D
            : UIColor(red: 0.550, green: 0.450, blue: 0.350, alpha: 1)  // #8C7359
        })

        // Light-mode accent variants
        static let amberLight = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.900, green: 0.650, blue: 0.200, alpha: 1)  // #E6A633
            : UIColor(red: 0.850, green: 0.600, blue: 0.150, alpha: 1)  // #D99926
        })
        static let goldLight = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.960, green: 0.850, blue: 0.400, alpha: 1)  // #F5D966
            : UIColor(red: 0.900, green: 0.780, blue: 0.320, alpha: 1)  // #E6C752
        })

        // Surfaces & backgrounds
        static let background = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.071, blue: 0.063, alpha: 1)  // #141210
            : UIColor(red: 0.980, green: 0.965, blue: 0.945, alpha: 1)  // #FAF6F1
        })
        static let surface = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.106, blue: 0.094, alpha: 1)  // #1E1B18
            : UIColor(red: 0.941, green: 0.922, blue: 0.890, alpha: 1)  // #F0EBE3
        })
        static let surface2 = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.149, blue: 0.133, alpha: 1)  // #2A2622
            : UIColor(red: 0.910, green: 0.878, blue: 0.831, alpha: 1)  // #E8E0D4
        })
        static let border = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.220, green: 0.200, blue: 0.180, alpha: 1)  // #38332E
            : UIColor(red: 0.860, green: 0.830, blue: 0.800, alpha: 1)  // #DBD4CC
        })

        // Text
        static let text = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.950, green: 0.930, blue: 0.900, alpha: 1)  // #F2EDE6
            : UIColor(red: 0.120, green: 0.100, blue: 0.080, alpha: 1)  // #1F1A14
        })
        static let text2 = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.750, green: 0.720, blue: 0.680, alpha: 1)  // #BFB8AD
            : UIColor(red: 0.350, green: 0.310, blue: 0.270, alpha: 1)  // #594F45
        })
        static let muted = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.500, green: 0.470, blue: 0.430, alpha: 1)  // #80786E
            : UIColor(red: 0.550, green: 0.510, blue: 0.470, alpha: 1)  // #8C8278
        })

        // Semantic — feedback
        static let correct = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.200, green: 0.700, blue: 0.350, alpha: 1)  // #33B359
            : UIColor(red: 0.150, green: 0.600, blue: 0.300, alpha: 1)  // #26994D
        })
        static let correctBg = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.100, green: 0.250, blue: 0.140, alpha: 1)  // #1A4024
            : UIColor(red: 0.900, green: 0.970, blue: 0.920, alpha: 1)  // #E6F8EB
        })
        static let wrong = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.850, green: 0.250, blue: 0.250, alpha: 1)  // #D94040
            : UIColor(red: 0.750, green: 0.200, blue: 0.200, alpha: 1)  // #BF3333
        })
        static let wrongBg = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.280, green: 0.100, blue: 0.100, alpha: 1)  // #471A1A
            : UIColor(red: 0.980, green: 0.910, blue: 0.910, alpha: 1)  // #FAE8E8
        })

        // Info / caution — mapped to Woodshop palette
        static let warning = amber
        static let caution = honey
        static let info    = Color(red: 0.35, green: 0.55, blue: 0.75) // warm steel-blue

        // Mastery level palette — 4-tier system
        // Struggling = cherry red, Learning = amber, Proficient = gold, Mastered = green
        static let masteryMastered   = correct   // green — spacing gate complete
        static let masteryProficient = gold       // gold — spacing gate in progress
        static let masteryLearning   = amber
        static let masteryStruggling = cherry

        // Legacy aliases — resolve to new tier colors
        static let masteryDeveloping = masteryLearning
        static let masteryBeginner   = masteryStruggling

        /// Returns the design-system mastery color for a 0–1 score.
        /// For heatmap cells where you can distinguish proficient vs mastered,
        /// use the `masteryColor(for:isMastered:)` overload instead.
        static func masteryColor(for score: Double) -> Color {
            switch score {
            case ..<0.50:  return masteryStruggling  // cherry
            case ..<0.75:  return masteryLearning    // amber
            default:       return masteryProficient  // gold
            }
        }

        /// Returns the design-system mastery color with full context.
        static func masteryColor(for score: Double, isMastered: Bool) -> Color {
            switch score {
            case ..<0.50:  return masteryStruggling  // cherry
            case ..<0.75:  return masteryLearning    // amber
            default:       return isMastered ? masteryMastered : masteryProficient  // green vs gold
            }
        }

        // Heatmap cell colors — flat, single color per tier.
        // Struggling: cherry red
        static let heatmapStruggling = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.769, green: 0.196, blue: 0.235, alpha: 1)  // #C4323C
            : UIColor(red: 0.690, green: 0.157, blue: 0.188, alpha: 1)  // #B02830
        })
        // Learning: amber
        static let heatmapLearning = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.831, green: 0.584, blue: 0.227, alpha: 1)  // #D4953A
            : UIColor(red: 0.753, green: 0.522, blue: 0.188, alpha: 1)  // #C08530
        })
        // Proficient: gold (spacing gate in progress)
        static let heatmapProficient = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 1.000, green: 0.843, blue: 0.000, alpha: 1)  // #FFD700
            : UIColor(red: 0.855, green: 0.718, blue: 0.000, alpha: 1)  // #DAB700
        })
        // Mastered: green (spacing gate complete — durable long-term memory)
        static let heatmapMastered = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1)  // #4CAF50
            : UIColor(red: 0.220, green: 0.557, blue: 0.235, alpha: 1)  // #388E3C
        })

        // Heatmap glow colors (for .shadow modifier on dark mode)
        static let heatmapStrugglingGlow  = Color(UIColor(red: 0.769, green: 0.196, blue: 0.235, alpha: 1))
        static let heatmapLearningGlow    = Color(UIColor(red: 0.831, green: 0.584, blue: 0.227, alpha: 1))
        static let heatmapProficientGlow  = Color(UIColor(red: 1.000, green: 0.843, blue: 0.000, alpha: 1))
        static let heatmapMasteredGlow    = Color(UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1))

        // Fretboard
        static let fretboardWood    = rosewood
        static let fretboardStrings = Color(.sRGB, red: 0.82, green: 0.82, blue: 0.82)

        /// Shared tuning color: green (in tune) → amber (close) → red (off).
        static func tuningColor(centsDeviation: Double, isActive: Bool) -> Color {
            guard isActive else { return muted }
            let absCents = abs(centsDeviation)
            if absCents <= 5  { return correct }
            if absCents <= 15 { return amber }
            return wrong
        }

    }

    // MARK: - Typography — Three-Family System (A2)
    enum Typography {
        // --- Montserrat (UI headings & labels) ---
        static let display:       Font = .custom("Montserrat-Black", size: 34)
        static let screenTitle:   Font = .custom("Montserrat-ExtraBold", size: 22)
        static let sectionHeader: Font = .custom("Montserrat-Bold", size: 15)
        static let bodyLabel:     Font = .custom("Montserrat-SemiBold", size: 14)
        static let smallLabel:    Font = .custom("Montserrat-SemiBold", size: 12)

        // --- Crimson Pro (accent / descriptive text) ---
        static let tagline:          Font = .custom("CrimsonPro-Italic", fixedSize: 15)
        static let accentDescription: Font = .custom("CrimsonPro-Italic", fixedSize: 14)

        // --- JetBrains Mono (data readouts) ---
        static let dataDisplay:  Font = .custom("JetBrainsMono-Bold", size: 18)
        static let dataSmall:    Font = .custom("JetBrainsMono-Medium", size: 12)
        static let sectionLabel: Font = .custom("JetBrainsMono-SemiBold", size: 10)

        // --- Additional sizes ---
        static let microLabel:   Font = .custom("Montserrat-SemiBold", size: 10)
        static let tinyLabel:    Font = .custom("Montserrat-SemiBold", size: 10)
        static let heatmapLabel: Font = .custom("Montserrat-Bold", size: 8)
        static let dataLarge:    Font = .custom("JetBrainsMono-Bold", size: 20)
        static let quizStatValue: Font = .custom("JetBrainsMono-Bold", size: 14)

        // --- Crimson Pro extended sizes ---
        static let accentBody:   Font = .custom("CrimsonPro-Italic", fixedSize: 20)
        static let accentLarge:  Font = .custom("CrimsonPro-Italic", fixedSize: 18)
        static let bodyText:     Font = .custom("CrimsonPro-Regular", fixedSize: 14)

        // --- JetBrains Mono extended sizes ---
        static let dataMicro:    Font = .custom("JetBrainsMono-Bold", size: 13)
        static let dataTiny:     Font = .custom("JetBrainsMono-Regular", size: 10)
        static let dataPip:      Font = .custom("JetBrainsMono-Bold", size: 10)
        static let dataChip:     Font = .custom("JetBrainsMono-SemiBold", size: 10)

        // --- Montserrat extended sizes ---
        static let promptLabel:  Font = .custom("Montserrat-SemiBold", size: 22)
        static let feedbackLabel: Font = .custom("Montserrat-SemiBold", size: 27)

        // --- App-specific display sizes (Montserrat) ---
        static let noteDisplay:  Font = .custom("Montserrat-Black", size: 80)
        static let heroNote:     Font = .custom("Montserrat-Black", size: 72)
        static let bpmDisplay:   Font = .custom("Montserrat-Bold", size: 64)
        static let quizNote:     Font = .custom("Montserrat-Black", size: 52)
        static let compactNote:  Font = .custom("Montserrat-Black", size: 36)
        static let largeNumber:  Font = .custom("Montserrat-Black", size: 40)
        static let subDisplay:   Font = .custom("Montserrat-ExtraBold", size: 28)
        static let mediumTitle:  Font = .custom("Montserrat-ExtraBold", size: 26)
        static let centsDisplay: Font = .custom("JetBrainsMono-SemiBold", size: 18)

        /// Helper for CAPS section labels with letter spacing
        static func capsLabel(_ text: String) -> Text {
            Text(text.uppercased())
                .font(sectionLabel)
                .tracking(1.5)
                .foregroundStyle(Colors.muted)
        }
    }

    // MARK: - Spacing (unchanged)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius (unchanged)
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // MARK: - Gradients (A4)
    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.cherry, Colors.amber],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let sunburst = LinearGradient(
            colors: [Colors.cherry, Colors.amber, Colors.honey],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let progress = LinearGradient(
            colors: [Colors.cherry, Colors.amber],
            startPoint: .top,
            endPoint: .bottom
        )
        static let warmSurface = LinearGradient(
            colors: [Colors.surface, Colors.surface2],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - View Modifiers (A4)

struct WoodshopCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(DesignSystem.Colors.border, lineWidth: colorScheme == .light ? 1 : 0)
            )
            .shadow(
                color: colorScheme == .light ? .black.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )
    }
}

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.bodyLabel)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Gradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.sectionLabel)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Colors.muted)
            .textCase(.uppercase)
    }
}

extension View {
    func woodshopCard() -> some View {
        modifier(WoodshopCardModifier())
    }

    func primaryButtonStyle() -> some View {
        modifier(PrimaryButtonModifier())
    }

    func sectionLabelStyle() -> some View {
        modifier(SectionLabelModifier())
    }
}

// MARK: - GradientSlider

/// A slider whose filled track uses a gradient instead of a flat color.
/// Drag only activates when the initial touch lands near the thumb,
/// preventing accidental value jumps when scrolling the page.
struct GradientSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 0
    var gradient: LinearGradient = DesignSystem.Gradients.primary

    // nil = not yet decided, true = on thumb, false = off thumb
    @State private var dragStartedOnThumb: Bool? = nil

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = 28
            let hitTarget: CGFloat = 44 // Generous touch target around thumb
            let usable = geo.size.width - thumbSize
            let thumbX = usable * CGFloat(fraction)
            let thumbCenter = thumbX + thumbSize / 2

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(DesignSystem.Colors.surface2)
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                // Gradient fill
                Capsule()
                    .fill(gradient)
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)
                    .padding(.leading, thumbSize / 2)

                // Thumb
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        // First event of this drag: decide if it started on the thumb
                        if dragStartedOnThumb == nil {
                            let dist = abs(drag.startLocation.x - thumbCenter)
                            dragStartedOnThumb = dist <= hitTarget / 2
                        }
                        guard dragStartedOnThumb == true else { return }

                        let raw = Double((drag.location.x - thumbSize / 2) / usable)
                        let clamped = min(max(raw, 0), 1)
                        var scaled = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        if step > 0 {
                            scaled = (scaled / step).rounded() * step
                        }
                        value = min(max(scaled, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        dragStartedOnThumb = nil
                    }
            )
        }
        .frame(height: 28)
    }
}
