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
            ? UIColor(red: 0.850, green: 0.550, blue: 0.100, alpha: 1)  // #D98C1A
            : UIColor(red: 0.750, green: 0.470, blue: 0.050, alpha: 1)  // #BF780D
        })
        static let honey = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.900, green: 0.720, blue: 0.250, alpha: 1)  // #E6B840
            : UIColor(red: 0.800, green: 0.620, blue: 0.150, alpha: 1)  // #CC9E26
        })
        static let gold = Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.950, green: 0.800, blue: 0.300, alpha: 1)  // #F2CC4D
            : UIColor(red: 0.850, green: 0.700, blue: 0.200, alpha: 1)  // #D9B333
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

        // Mastery level palette — sunburst progression
        static let masteryMastered   = correct
        static let masteryProficient = gold
        static let masteryDeveloping = amber
        static let masteryBeginner   = cherry

        /// Returns the design-system mastery color for a 0–1 score.
        static func masteryColor(for score: Double) -> Color {
            switch score {
            case ..<0.4:     return masteryBeginner    // cherry
            case 0.4..<0.7:  return masteryDeveloping  // amber
            case 0.7..<0.9:  return masteryProficient  // gold
            default:         return masteryMastered     // green/correct
            }
        }

        // Fretboard
        static let fretboardWood    = rosewood
        static let fretboardStrings = Color(.sRGB, red: 0.82, green: 0.82, blue: 0.82)

    }

    // MARK: - Typography — Three-Family System (A2)
    enum Typography {
        // --- Montserrat (UI headings & labels) ---
        static let display:       Font = .custom("Montserrat-Black", size: 34)
        static let screenTitle:   Font = .custom("Montserrat-ExtraBold", size: 22)
        static let sectionHeader: Font = .custom("Montserrat-Bold", size: 15)
        static let bodyLabel:     Font = .custom("Montserrat-SemiBold", size: 14)
        static let smallLabel:    Font = .custom("Montserrat-SemiBold", size: 11)

        // --- Crimson Pro (accent / descriptive text) ---
        static let tagline:          Font = .custom("CrimsonPro-Italic", size: 15)
        static let accentDescription: Font = .custom("CrimsonPro-Italic", size: 14)

        // --- JetBrains Mono (data readouts) ---
        static let dataDisplay:  Font = .custom("JetBrainsMono-Bold", size: 18)
        static let dataSmall:    Font = .custom("JetBrainsMono-Medium", size: 11)
        static let sectionLabel: Font = .custom("JetBrainsMono-SemiBold", size: 9.5)

        // --- Additional sizes ---
        static let microLabel:   Font = .custom("Montserrat-SemiBold", size: 10)
        static let tinyLabel:    Font = .custom("Montserrat-SemiBold", size: 8)
        static let heatmapLabel: Font = .custom("Montserrat-Bold", size: 7)
        static let dataLarge:    Font = .custom("JetBrainsMono-Bold", size: 20)
        static let quizStatValue: Font = .custom("JetBrainsMono-Bold", size: 14)

        // --- App-specific display sizes (Montserrat) ---
        static let noteDisplay:  Font = .custom("Montserrat-Black", size: 80)
        static let heroNote:     Font = .custom("Montserrat-Black", size: 72)
        static let bpmDisplay:   Font = .custom("Montserrat-Bold", size: 64)
        static let quizNote:     Font = .custom("Montserrat-Black", size: 52)
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
