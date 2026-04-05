import SwiftUI

// MARK: - SwiftUI Conversions for DesignModel types
// These extensions provide the bridge between serializable model types and SwiftUI values.

extension HorizontalAlignmentType {
    public var swiftUIValue: HorizontalAlignment {
        switch self {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }
}

extension VerticalAlignmentType {
    public var swiftUIValue: VerticalAlignment {
        switch self {
        case .top:               return .top
        case .center:            return .center
        case .bottom:            return .bottom
        case .firstTextBaseline: return .firstTextBaseline
        case .lastTextBaseline:  return .lastTextBaseline
        }
    }
}

extension AlignmentType {
    public var swiftUIValue: Alignment {
        switch self {
        case .topLeading:    return .topLeading
        case .top:           return .top
        case .topTrailing:   return .topTrailing
        case .leading:       return .leading
        case .center:        return .center
        case .trailing:      return .trailing
        case .bottomLeading: return .bottomLeading
        case .bottom:        return .bottom
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

extension TextStyleType {
    public var swiftUIFont: Font {
        switch self {
        case .largeTitle:  return .largeTitle
        case .title:       return .title
        case .title2:      return .title2
        case .title3:      return .title3
        case .headline:    return .headline
        case .subheadline: return .subheadline
        case .body:        return .body
        case .callout:     return .callout
        case .footnote:    return .footnote
        case .caption:     return .caption
        case .caption2:    return .caption2
        }
    }

    public var pointSize: CGFloat {
        switch self {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .subheadline: return 15
        case .body:        return 17
        case .callout:     return 16
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        }
    }
}

extension FontWeightType {
    public var swiftUIValue: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }
}

extension FontDesignType {
    public var swiftUIValue: Font.Design {
        switch self {
        case .default:     return .default
        case .rounded:     return .rounded
        case .serif:       return .serif
        case .monospaced:  return .monospaced
        }
    }
}

extension EdgeSetType {
    public var swiftUIValue: Edge.Set {
        switch self {
        case .all:        return .all
        case .top:        return .top
        case .bottom:     return .bottom
        case .leading:    return .leading
        case .trailing:   return .trailing
        case .horizontal: return .horizontal
        case .vertical:   return .vertical
        }
    }
}

extension MaterialType {
    public var swiftUIMaterial: Material {
        switch self {
        case .ultraThin:    return .ultraThinMaterial
        case .thin:         return .thinMaterial
        case .regular:      return .regularMaterial
        case .thick:        return .thickMaterial
        case .ultraThick:   return .ultraThickMaterial
        case .liquidGlass:  return .ultraThinMaterial // Approximation on macOS
        }
    }
}

extension GridColumnConfig {
    public var swiftUIGridItem: GridItem {
        switch type {
        case .flexible: return GridItem(.flexible())
        case .fixed:    return GridItem(.fixed(size ?? 100))
        case .adaptive: return GridItem(.adaptive(minimum: size ?? 80))
        }
    }
}

extension DesignColor {
    public var swiftUIColor: Color {
        switch self {
        case .custom(let r, let g, let b, let opacity):
            return Color(red: r, green: g, blue: b, opacity: opacity)
        case .system(let systemColor):
            return systemColor.swiftUIColor
        }
    }
}

extension DesignColor.SystemColor {
    public var swiftUIColor: Color {
        switch self {
        case .red:       return .red
        case .orange:    return .orange
        case .yellow:    return .yellow
        case .green:     return .green
        case .mint:      return .mint
        case .teal:      return .teal
        case .cyan:      return .cyan
        case .blue:      return .blue
        case .indigo:    return .indigo
        case .purple:    return .purple
        case .pink:      return .pink
        case .brown:     return .brown
        case .gray:      return .gray
        case .gray2:     return Color(nsColor: .systemGray)
        case .gray3:     return Color(nsColor: .systemGray)
        case .gray4:     return Color(nsColor: .systemGray)
        case .gray5:     return Color(nsColor: .systemGray)
        case .gray6:     return Color(nsColor: .systemGray)
        case .primary:   return .primary
        case .secondary: return .secondary
        case .accentColor: return .accentColor
        case .label:     return Color(nsColor: .labelColor)
        case .secondaryLabel: return Color(nsColor: .secondaryLabelColor)
        case .tertiaryLabel:  return Color(nsColor: .tertiaryLabelColor)
        case .quaternaryLabel: return Color(nsColor: .quaternaryLabelColor)
        case .systemBackground: return Color(nsColor: .windowBackgroundColor)
        case .secondarySystemBackground: return Color(nsColor: .controlBackgroundColor)
        case .tertiarySystemBackground: return Color(nsColor: .textBackgroundColor)
        case .systemGroupedBackground: return Color(nsColor: .windowBackgroundColor)
        case .secondarySystemGroupedBackground: return Color(nsColor: .controlBackgroundColor)
        case .tertiarySystemGroupedBackground: return Color(nsColor: .textBackgroundColor)
        case .systemFill: return Color(nsColor: .controlColor)
        case .secondarySystemFill: return Color(nsColor: .controlColor)
        case .tertiarySystemFill: return Color(nsColor: .controlColor)
        case .quaternarySystemFill: return Color(nsColor: .controlColor)
        case .separator: return Color(nsColor: .separatorColor)
        case .opaqueSeparator: return Color(nsColor: .separatorColor)
        }
    }
}
