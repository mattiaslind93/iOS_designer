import Foundation
import CoreGraphics

/// Snapping configuration for the canvas.
public struct SnapSettings: Codable, Hashable {
    public var isEnabled: Bool
    public var mode: SnapMode
    public var showGuides: Bool

    public init(isEnabled: Bool = false, mode: SnapMode = .grid8pt, showGuides: Bool = true) {
        self.isEnabled = isEnabled
        self.mode = mode
        self.showGuides = showGuides
    }

    /// Snap a point to the current grid
    public func snap(_ point: CGPoint) -> CGPoint {
        guard isEnabled else { return point }
        let gridSize = mode.gridSize
        return CGPoint(
            x: (point.x / gridSize).rounded() * gridSize,
            y: (point.y / gridSize).rounded() * gridSize
        )
    }

    /// Snap a single value
    public func snap(_ value: CGFloat) -> CGFloat {
        guard isEnabled else { return value }
        let gridSize = mode.gridSize
        return (value / gridSize).rounded() * gridSize
    }
}

/// Available snapping modes with different grid sizes and layout guides.
public enum SnapMode: String, Codable, Hashable, CaseIterable, Identifiable {
    case grid4pt    = "4pt Grid"
    case grid8pt    = "8pt Grid"
    case grid16pt   = "16pt Grid"
    case iosLayout  = "iOS Layout"

    public var id: String { rawValue }

    public var gridSize: CGFloat {
        switch self {
        case .grid4pt:   return 4
        case .grid8pt:   return 8
        case .grid16pt:  return 16
        case .iosLayout: return 8  // Base grid for iOS layout
        }
    }

    /// iOS standard layout margins and guides (in points)
    public var layoutGuides: [CGFloat] {
        switch self {
        case .iosLayout:
            return [
                16,   // Standard leading/trailing margin
                20,   // Alternative margin
                44,   // Navigation bar / min tap target
                49,   // Tab bar height
                62,   // Safe area top (Dynamic Island)
                34,   // Safe area bottom (home indicator)
            ]
        default:
            return []
        }
    }

    public var displayName: String { rawValue }
}
