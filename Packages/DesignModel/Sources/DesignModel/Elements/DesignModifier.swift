import Foundation
import CoreGraphics

/// Ordered modifier stack — directly maps to SwiftUI view modifiers.
/// Applied in order during both canvas rendering and code generation.
public enum DesignModifier: Codable, Hashable {

    // MARK: - Layout

    case frame(width: CGFloat?, height: CGFloat?, minWidth: CGFloat?, maxWidth: CGFloat?,
               minHeight: CGFloat?, maxHeight: CGFloat?, alignment: AlignmentType?)
    case padding(edges: EdgeSetType, amount: CGFloat)
    case layoutPriority(Double)

    // MARK: - Appearance

    case foregroundStyle(DesignColor)
    case background(DesignColor)
    case backgroundMaterial(MaterialType)
    case tint(DesignColor)
    case opacity(Double)

    // MARK: - Typography

    case font(style: TextStyleType?, size: CGFloat?, weight: FontWeightType?, design: FontDesignType?)
    case multilineTextAlignment(TextAlignmentType)
    case lineLimit(Int?)
    case lineSpacing(CGFloat)

    // MARK: - Shape & Clipping

    case cornerRadius(CGFloat)
    case clipShape(ShapeType)
    case overlay(ShapeType, color: DesignColor, lineWidth: CGFloat)
    case mask(ShapeType)

    // MARK: - Effects

    case shadow(color: DesignColor, radius: CGFloat, x: CGFloat, y: CGFloat)
    case blur(radius: CGFloat)
    case glassEffect(GlassStyleType)
    case glassEffectContainer

    // MARK: - Interaction

    case disabled(Bool)
    case allowsHitTesting(Bool)
    case contentShape(ShapeType)

    // MARK: - Positioning

    case offset(x: CGFloat, y: CGFloat)
    case rotationEffect(degrees: Double)
    case scaleEffect(x: CGFloat, y: CGFloat)
    case zIndex(Double)

    // MARK: - Animation

    case animation(AnimationPreset, trigger: String?)
    case transition(TransitionType)
    case matchedGeometryID(String)
}

// MARK: - Supporting Types

public enum EdgeSetType: String, Codable, Hashable, CaseIterable {
    case all, top, bottom, leading, trailing
    case horizontal, vertical
}

public enum FontWeightType: String, Codable, Hashable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

public enum FontDesignType: String, Codable, Hashable, CaseIterable {
    case `default`, rounded, serif, monospaced
}

public enum TextAlignmentType: String, Codable, Hashable, CaseIterable {
    case leading, center, trailing
}

public enum ShapeType: String, Codable, Hashable, CaseIterable {
    case rectangle, roundedRectangle, circle, capsule, ellipse
}

public enum MaterialType: String, Codable, Hashable, CaseIterable {
    case ultraThin, thin, regular, thick, ultraThick
    case liquidGlass
}

public enum GlassStyleType: String, Codable, Hashable, CaseIterable {
    case regular, clear
}

public enum TransitionType: String, Codable, Hashable, CaseIterable {
    case opacity, slide, scale, push, move, offset
    case asymmetric
}
