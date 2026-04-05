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

    // MARK: - Hex Conversion

    /// Returns hex string like "#FF0000" for custom colors, or system color name for system colors.
    public var hexString: String {
        switch self {
        case .custom(let r, let g, let b, _):
            let ri = Int(r * 255)
            let gi = Int(g * 255)
            let bi = Int(b * 255)
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        case .system(let sc):
            return sc.rawValue
        }
    }

    /// Parse a hex string like "#FF0000" or "FF0000" into a DesignColor.
    public static func fromHex(_ hex: String) -> DesignColor? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let int = UInt64(str, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return .custom(red: r, green: g, blue: b, opacity: 1.0)
    }
}
