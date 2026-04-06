import SwiftUI
import DesignModel

/// Renders a VectorPath as a SwiftUI Path with optional fill and stroke.
public struct VectorPathView: View {
    let path: VectorPath
    let stroke: VectorStrokeStyle?
    let fill: DesignColor?

    public init(path: VectorPath, stroke: VectorStrokeStyle?, fill: DesignColor?) {
        self.path = path
        self.stroke = stroke
        self.fill = fill
    }

    public var body: some View {
        ZStack {
            // Fill layer
            if let fill {
                swiftUIPath
                    .fill(fill.swiftUIColor, style: FillStyle(eoFill: path.fillRule == .evenOdd))
            }

            // Stroke layer
            if let stroke {
                swiftUIPath
                    .stroke(
                        stroke.color.swiftUIColor,
                        style: StrokeStyle(
                            lineWidth: stroke.width,
                            lineCap: stroke.lineCap.swiftUIValue,
                            lineJoin: stroke.lineJoin.swiftUIValue,
                            miterLimit: stroke.miterLimit,
                            dash: stroke.dashPattern,
                            dashPhase: 0
                        )
                    )
            }

            // If neither fill nor stroke, show a default stroke so it's visible
            if fill == nil && stroke == nil {
                swiftUIPath
                    .stroke(Color.primary, lineWidth: 2)
            }
        }
    }

    /// Convert VectorPath to SwiftUI Path
    private var swiftUIPath: Path {
        Path { p in
            guard !path.points.isEmpty else { return }

            p.move(to: path.points[0].position)

            for i in 1..<path.points.count {
                let prev = path.points[i - 1]
                let curr = path.points[i]
                addSegment(to: &p, from: prev, to: curr)
            }

            // Close path: connect last point back to first
            if path.isClosed && path.points.count > 1 {
                let last = path.points[path.points.count - 1]
                let first = path.points[0]
                addSegment(to: &p, from: last, to: first)
                p.closeSubpath()
            }
        }
    }

    /// Add a segment between two PathPoints, choosing line vs curve based on handles.
    private func addSegment(to p: inout Path, from prev: PathPoint, to curr: PathPoint) {
        let hasHandleOut = prev.handleOut != nil
        let hasHandleIn = curr.handleIn != nil

        if hasHandleOut && hasHandleIn {
            // Cubic bezier
            p.addCurve(
                to: curr.position,
                control1: prev.handleOutAbsolute!,
                control2: curr.handleInAbsolute!
            )
        } else if hasHandleOut {
            // Quadratic with outgoing handle
            p.addQuadCurve(to: curr.position, control: prev.handleOutAbsolute!)
        } else if hasHandleIn {
            // Quadratic with incoming handle
            p.addQuadCurve(to: curr.position, control: curr.handleInAbsolute!)
        } else {
            // Straight line
            p.addLine(to: curr.position)
        }
    }
}

// MARK: - SwiftUI Conversions for Vector Types

extension LineCapType {
    public var swiftUIValue: CGLineCap {
        switch self {
        case .butt:   return .butt
        case .round:  return .round
        case .square: return .square
        }
    }
}

extension LineJoinType {
    public var swiftUIValue: CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}
