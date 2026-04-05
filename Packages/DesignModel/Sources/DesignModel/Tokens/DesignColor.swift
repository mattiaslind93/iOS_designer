import Foundation

/// A serializable color representation independent of SwiftUI.
/// Supports both custom RGBA colors and iOS semantic system colors.
public enum DesignColor: Codable, Hashable {
    case custom(red: Double, green: Double, blue: Double, opacity: Double)
    case system(SystemColor)

    public static let white = DesignColor.custom(red: 1, green: 1, blue: 1, opacity: 1)
    public static let black = DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 1)
    public static let clear = DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 0)

    public enum SystemColor: String, Codable, Hashable, CaseIterable {
        // Standard colors
        case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown
        case gray, gray2, gray3, gray4, gray5, gray6

        // Semantic colors
        case primary, secondary
        case accentColor

        // Label colors
        case label, secondaryLabel, tertiaryLabel, quaternaryLabel

        // Background colors
        case systemBackground, secondarySystemBackground, tertiarySystemBackground
        case systemGroupedBackground, secondarySystemGroupedBackground, tertiarySystemGroupedBackground

        // Fill colors
        case systemFill, secondarySystemFill, tertiarySystemFill, quaternarySystemFill

        // Separator
        case separator, opaqueSeparator
    }
}
