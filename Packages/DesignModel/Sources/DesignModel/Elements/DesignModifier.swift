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
    case glassConfig(GlassConfig)
    case glassEffectContainer
    case carPaint(CarPaintConfig)

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

/// Apple iOS 26 Liquid Glass styles.
/// - `regular`: Default glass. Medium translucency, full adaptivity.
/// - `clear`: High translucency, for media-rich backgrounds. Needs dimming layer.
/// - `identity`: No visual effect (conditional disable without layout change).
public enum GlassStyleType: String, Codable, Hashable, CaseIterable {
    case regular
    case clear
    case identity
}

/// Glass effect shape for clipping the glass material
public enum GlassShapeType: String, Codable, Hashable, CaseIterable {
    case capsule    // default
    case circle
    case roundedRectangle
    case rectangle
    case ellipse
}

/// Liquid Glass configuration matching Apple's real API.
///
/// Maps to: `.glassEffect(.regular.tint(.orange).interactive(), in: .capsule)`
/// - `style`: regular, clear, identity
/// - `tintColor`: Semantic color (conveys meaning, not decorative)
/// - `isInteractive`: Enables press-scale, bounce, shimmer, touch illumination
/// - `shape`: Glass clipping shape (capsule default)
/// - `containerSpacing`: If set, wraps in GlassEffectContainer(spacing:)
///   Elements within this distance morph/blend together during animation
public struct GlassConfig: Codable, Hashable {
    public var style: GlassStyleType
    public var tintColor: DesignColor?
    /// Tint intensity 0.0–1.0 (how saturated/visible the tint color is)
    public var tintIntensity: Double
    public var isInteractive: Bool
    public var shape: GlassShapeType

    public init(
        style: GlassStyleType = .regular,
        tintColor: DesignColor? = nil,
        tintIntensity: Double = 0.3,
        isInteractive: Bool = false,
        shape: GlassShapeType = .capsule
    ) {
        self.style = style
        self.tintColor = tintColor
        self.tintIntensity = tintIntensity
        self.isInteractive = isInteractive
        self.shape = shape
    }

    public static let `default` = GlassConfig()
}

// MARK: - Car Paint Material

/// Car paint configuration for metallic clearcoat material.
/// Rendered with 3 layers: base coat, metallic flake, clearcoat.
/// Reacts to device motion (tilt) for realistic specular highlights.
public struct CarPaintConfig: Codable, Hashable {
    /// Base coat color (deep paint color)
    public var baseColor: DesignColor
    /// Metallic flake intensity 0.0–1.0
    public var flakeIntensity: Double
    /// Metallic flake scale (size of sparkle noise)
    public var flakeScale: Double
    /// Clearcoat intensity 0.0–1.0 (specular sharpness)
    public var clearcoatIntensity: Double
    /// Clearcoat sharpness 0.0–1.0 (how tight the spec highlight is)
    public var clearcoatSharpness: Double
    /// Fresnel edge brightening 0.0–1.0
    public var fresnelIntensity: Double
    /// Whether the material reacts to device tilt
    public var reactsToMotion: Bool

    public init(
        baseColor: DesignColor = .custom(red: 0.7, green: 0.05, blue: 0.05, opacity: 1.0),
        flakeIntensity: Double = 0.6,
        flakeScale: Double = 0.5,
        clearcoatIntensity: Double = 0.8,
        clearcoatSharpness: Double = 0.7,
        fresnelIntensity: Double = 0.4,
        reactsToMotion: Bool = true
    ) {
        self.baseColor = baseColor
        self.flakeIntensity = flakeIntensity
        self.flakeScale = flakeScale
        self.clearcoatIntensity = clearcoatIntensity
        self.clearcoatSharpness = clearcoatSharpness
        self.fresnelIntensity = fresnelIntensity
        self.reactsToMotion = reactsToMotion
    }

    public static let ferrariRed = CarPaintConfig()
    public static let midnightBlue = CarPaintConfig(
        baseColor: .custom(red: 0.05, green: 0.08, blue: 0.25, opacity: 1.0)
    )
    public static let titaniumSilver = CarPaintConfig(
        baseColor: .custom(red: 0.55, green: 0.56, blue: 0.58, opacity: 1.0),
        flakeIntensity: 0.8, clearcoatIntensity: 0.9
    )
    public static let deepBlack = CarPaintConfig(
        baseColor: .custom(red: 0.05, green: 0.05, blue: 0.07, opacity: 1.0),
        flakeIntensity: 0.3, clearcoatIntensity: 0.95
    )
    public static let britishRacingGreen = CarPaintConfig(
        baseColor: .custom(red: 0.0, green: 0.25, blue: 0.1, opacity: 1.0)
    )
}

public enum TransitionType: String, Codable, Hashable, CaseIterable {
    case opacity, slide, scale, push, move, offset
    case asymmetric
}
