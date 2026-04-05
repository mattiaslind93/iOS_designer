import Foundation
import CoreGraphics

/// iPhone device definitions with exact point dimensions and safe area insets.
public enum DeviceFrame: String, Codable, Hashable, CaseIterable, Identifiable {
    case iPhone16ProMax
    case iPhone16Pro
    case iPhone16
    case iPhone16e

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iPhone16ProMax: return "iPhone 16 Pro Max"
        case .iPhone16Pro:    return "iPhone 16 Pro"
        case .iPhone16:       return "iPhone 16"
        case .iPhone16e:      return "iPhone 16e"
        }
    }

    /// Screen size in points
    public var size: CGSize {
        switch self {
        case .iPhone16ProMax: return CGSize(width: 440, height: 956)
        case .iPhone16Pro:    return CGSize(width: 393, height: 852)
        case .iPhone16:       return CGSize(width: 390, height: 844)
        case .iPhone16e:      return CGSize(width: 390, height: 844)
        }
    }

    /// Safe area insets in portrait (top, leading, bottom, trailing)
    public var safeAreaInsets: SafeAreaInsets {
        switch self {
        case .iPhone16ProMax:
            return SafeAreaInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        case .iPhone16Pro:
            return SafeAreaInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        case .iPhone16:
            return SafeAreaInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        case .iPhone16e:
            return SafeAreaInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
        }
    }

    public var hasDynamicIsland: Bool {
        switch self {
        case .iPhone16ProMax, .iPhone16Pro, .iPhone16: return true
        case .iPhone16e: return false
        }
    }

    /// Corner radius of the device screen
    public var screenCornerRadius: CGFloat {
        switch self {
        case .iPhone16ProMax: return 62
        case .iPhone16Pro:    return 55
        case .iPhone16:       return 55
        case .iPhone16e:      return 50
        }
    }

    /// Scale factor
    public var scaleFactor: CGFloat { 3.0 }
}

public struct SafeAreaInsets: Codable, Hashable {
    public let top: CGFloat
    public let leading: CGFloat
    public let bottom: CGFloat
    public let trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}
