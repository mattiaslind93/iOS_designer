import Foundation

/// Pre-configured animation types following Apple's iOS animation guidelines.
public enum AnimationPreset: String, Codable, Hashable, CaseIterable, Identifiable {
    // Spring animations
    case bouncy
    case snappy
    case smooth
    case soft

    // Timing curve animations
    case easeIn
    case easeOut
    case easeInOut
    case linear

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bouncy:    return "Bouncy"
        case .snappy:    return "Snappy"
        case .smooth:    return "Smooth"
        case .soft:      return "Soft"
        case .easeIn:    return "Ease In"
        case .easeOut:   return "Ease Out"
        case .easeInOut: return "Ease In Out"
        case .linear:    return "Linear"
        }
    }

    public var isSpring: Bool {
        switch self {
        case .bouncy, .snappy, .smooth, .soft: return true
        default: return false
        }
    }

    /// Spring response (duration-like parameter)
    public var response: Double? {
        switch self {
        case .bouncy:  return 0.5
        case .snappy:  return 0.3
        case .smooth:  return 0.5
        case .soft:    return 0.7
        default:       return nil
        }
    }

    /// Spring damping fraction (0 = oscillate forever, 1 = no bounce)
    public var dampingFraction: Double? {
        switch self {
        case .bouncy:  return 0.5
        case .snappy:  return 0.7
        case .smooth:  return 0.85
        case .soft:    return 0.9
        default:       return nil
        }
    }

    /// Default duration for timing-curve animations
    public var duration: Double {
        switch self {
        case .bouncy, .snappy, .smooth, .soft: return 0.5
        case .easeIn, .easeOut, .easeInOut: return 0.35
        case .linear: return 0.25
        }
    }
}
