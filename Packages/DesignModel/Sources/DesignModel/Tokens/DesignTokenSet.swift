import Foundation
import CoreGraphics

/// Project-level design tokens: spacing, corner radii, colors, typography.
/// These map to the exported Theme/ files in code generation.
public struct DesignTokenSet: Codable, Hashable {
    public var spacingScale: [CGFloat]
    public var cornerRadii: [CGFloat]
    public var accentColor: DesignColor
    public var backgroundColor: DesignColor
    public var textColor: DesignColor

    public init(
        spacingScale: [CGFloat] = Self.defaultSpacingScale,
        cornerRadii: [CGFloat] = Self.defaultCornerRadii,
        accentColor: DesignColor = .system(.accentColor),
        backgroundColor: DesignColor = .system(.systemBackground),
        textColor: DesignColor = .system(.label)
    ) {
        self.spacingScale = spacingScale
        self.cornerRadii = cornerRadii
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    // MARK: - Defaults (Apple HIG 8pt grid)

    public static let defaultSpacingScale: [CGFloat] = [4, 8, 12, 16, 20, 24, 32, 40, 48]
    public static let defaultCornerRadii: [CGFloat] = [4, 8, 12, 16, 20, 24]
}
