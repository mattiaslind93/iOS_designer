import Foundation
import CoreGraphics

/// Discriminates between the different types of design elements.
/// Each case maps directly to a SwiftUI view for both canvas rendering and code generation.
public enum ElementPayload: Codable, Hashable {

    // MARK: - Layout Containers

    case vStack(spacing: CGFloat?, alignment: HorizontalAlignmentType)
    case hStack(spacing: CGFloat?, alignment: VerticalAlignmentType)
    case zStack(alignment: AlignmentType)
    case lazyVGrid(columns: [GridColumnConfig], spacing: CGFloat?)
    case lazyHGrid(rows: [GridColumnConfig], spacing: CGFloat?)
    case scrollView(axis: AxisType)

    // MARK: - Content

    case text(content: String, style: TextStyleType?)
    case image(systemName: String?, assetName: String?)
    case rectangle
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case spacer(minLength: CGFloat?)
    case divider
    case color(designColor: DesignColor)

    // MARK: - Navigation (iOS 26 Liquid Glass)

    case navigationStack(title: String, displayMode: TitleDisplayMode)
    case tabView(tabs: [TabItemConfig])
    case sheet(detents: [SheetDetent])

    // MARK: - Controls

    case button(title: String, style: ButtonStyleType)
    case textField(placeholder: String)
    case secureField(placeholder: String)
    case toggle(label: String, isOn: Bool)
    case slider(minValue: Double, maxValue: Double, value: Double)
    case picker(label: String, options: [String], selection: Int)
    case stepper(label: String, minValue: Int, maxValue: Int, value: Int)
    case datePicker(label: String)
    case progressView(style: ProgressStyleType, value: Double?)
    case label(title: String, systemImage: String)

    // MARK: - Containers

    case list(style: ListStyleType)
    case form
    case group
}

// MARK: - Supporting Types

public enum HorizontalAlignmentType: String, Codable, Hashable, CaseIterable {
    case leading, center, trailing
}

public enum VerticalAlignmentType: String, Codable, Hashable, CaseIterable {
    case top, center, bottom, firstTextBaseline, lastTextBaseline
}

public enum AlignmentType: String, Codable, Hashable, CaseIterable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
}

public enum AxisType: String, Codable, Hashable, CaseIterable {
    case vertical, horizontal
}

public enum TextStyleType: String, Codable, Hashable, CaseIterable {
    case largeTitle, title, title2, title3
    case headline, subheadline
    case body, callout, footnote
    case caption, caption2
}

public enum TitleDisplayMode: String, Codable, Hashable, CaseIterable {
    case automatic, inline, large
}

public enum ButtonStyleType: String, Codable, Hashable, CaseIterable {
    case automatic, borderedProminent, bordered, borderless, plain
    case glass, glassProminent
}

public enum ListStyleType: String, Codable, Hashable, CaseIterable {
    case automatic, insetGrouped, grouped, inset, plain, sidebar
}

public enum ProgressStyleType: String, Codable, Hashable, CaseIterable {
    case linear, circular
}

public enum SheetDetent: String, Codable, Hashable, CaseIterable {
    case medium, large
}

public struct TabItemConfig: Codable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var systemImage: String

    public init(id: UUID = UUID(), title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

public struct GridColumnConfig: Codable, Hashable {
    public var type: GridColumnType
    public var size: CGFloat?

    public init(type: GridColumnType, size: CGFloat? = nil) {
        self.type = type
        self.size = size
    }

    public enum GridColumnType: String, Codable, Hashable, CaseIterable {
        case flexible, fixed, adaptive
    }
}
