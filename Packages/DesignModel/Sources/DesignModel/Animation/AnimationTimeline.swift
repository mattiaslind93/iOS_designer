import Foundation

/// Keynote-like animation timeline for a design page.
/// Each element can have multiple animation tracks with keyframes.
public struct AnimationTimeline: Codable, Hashable {
    public var tracks: [AnimationTrack]

    public init(tracks: [AnimationTrack] = []) {
        self.tracks = tracks
    }
}

/// A single animation track tied to an element.
public struct AnimationTrack: Codable, Hashable, Identifiable {
    public let id: UUID
    public var elementID: UUID
    public var keyframes: [Keyframe]
    public var delay: Double
    public var repeatCount: Int
    public var autoreverses: Bool

    public init(
        id: UUID = UUID(),
        elementID: UUID,
        keyframes: [Keyframe] = [],
        delay: Double = 0,
        repeatCount: Int = 1,
        autoreverses: Bool = false
    ) {
        self.id = id
        self.elementID = elementID
        self.keyframes = keyframes
        self.delay = delay
        self.repeatCount = repeatCount
        self.autoreverses = autoreverses
    }
}

/// A single keyframe in an animation track.
public struct Keyframe: Codable, Hashable, Identifiable {
    public let id: UUID
    public var time: Double
    public var property: AnimatableProperty
    public var value: Double
    public var preset: AnimationPreset

    public init(
        id: UUID = UUID(),
        time: Double,
        property: AnimatableProperty,
        value: Double,
        preset: AnimationPreset = .smooth
    ) {
        self.id = id
        self.time = time
        self.property = property
        self.value = value
        self.preset = preset
    }
}

/// Properties that can be animated.
public enum AnimatableProperty: String, Codable, Hashable, CaseIterable {
    case opacity
    case scaleX, scaleY
    case offsetX, offsetY
    case rotation
    case blur
    case cornerRadius
}
