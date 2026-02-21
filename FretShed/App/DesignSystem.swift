import SwiftUI

enum DesignSystem {

    // MARK: - Colors (Task 2.2)
    enum Colors {
        // Brand
        static let primary   = Color.indigo
        static let secondary = Color.teal

        // Semantic
        static let success = Color.green
        static let warning = Color.orange
        static let error   = Color.red
        static let caution = Color.yellow
        static let info    = Color.blue

        // Text (system-adaptive)
        static let text          = Color.primary
        static let textSecondary = Color.secondary

        // Surfaces (system-adaptive)
        static let surface          = Color(uiColor: .secondarySystemGroupedBackground)
        static let surfaceSecondary = Color(uiColor: .tertiarySystemGroupedBackground)

        // Custom fretboard pigments (extracted from FretboardView)
        static let fretboardWood    = Color(.sRGB, red: 0.20, green: 0.14, blue: 0.07)
        static let fretboardStrings = Color(.sRGB, red: 0.82, green: 0.82, blue: 0.82)

        // Mastery level palette
        static let masteryMastered   = Color.green
        static let masteryProficient = Color.blue
        static let masteryDeveloping = Color.orange
        static let masteryBeginner   = Color.red
    }

    // MARK: - Typography (Task 2.3)
    enum Typography {
        // Standard scale
        static let title:    Font = .title2.weight(.bold)
        static let headline: Font = .headline
        static let body:     Font = .body
        static let caption:  Font = .caption.weight(.semibold)
        static let caption2: Font = .caption2

        // App-specific display fonts
        static let noteDisplay:  Font = .system(size: 80, weight: .black,    design: .rounded)
        static let bpmDisplay:   Font = .system(size: 72, weight: .bold,     design: .rounded)
        static let centsDisplay: Font = .system(size: 18, weight: .semibold, design: .monospaced)
    }

    // MARK: - Spacing (Task 2.4)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
}
