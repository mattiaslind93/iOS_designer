import SwiftUI
import DesignModel

/// Renders a VectorPath as a SwiftUI Path with optional fill and stroke.
/// Dynamically sizes itself to the path's bounding rect plus stroke padding,
/// so the selection overlay and clipping always match the actual shape.
public struct VectorPathView: View {
    let path: VectorPath
    let stroke: VectorStrokeStyle?
    let fill: DesignColor?

    public init(path: VectorPath, stroke: VectorStrokeStyle?, fill: DesignColor?) {
        self.path = path
        self.stroke = stroke
        self.fill = fill
    }

    /// Padding around the path bounds to account for stroke width
    private var strokePadding: CGFloat {
        guard let stroke else { return 1 }
        return stroke.width / 2 + 1
    }

    /// The bounding rect of the path
    private var bounds: CGRect {
        let b = path.boundingRect
        guard b.width > 0 || b.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        return b
    }

    /// Total size including stroke padding
    private var totalSize: CGSize {
        let b = bounds
        let pad = strokePadding * 2
        return CGSize(
            width: max(b.width + pad, 1),
            height: max(b.height + pad, 1)
        )
    }

    public var body: some View {
        Canvas { context, size in
            // Translate so path origin (bounds.minX, bounds.minY) maps to (strokePadding, strokePadding)
            let offsetX = -bounds.minX + strokePadding
            let offsetY = -bounds.minY + strokePadding

            let swiftPath = buildPath(offsetX: offsetX, offsetY: offsetY)

            // Fill
            if let fill {
                context.fill(swiftPath, with: .color(fill.swiftUIColor), style: FillStyle(eoFill: path.fillRule == .evenOdd))
            }

            // Stroke
            if let stroke {
                context.stroke(
                    swiftPath,
                    with: .color(stroke.color.swiftUIColor),
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

            // Default stroke if neither fill nor stroke
            if fill == nil && stroke == nil {
                context.stroke(swiftPath, with: .color(.primary), lineWidth: 2)
            }
        }
        .frame(width: totalSize.width, height: totalSize.height)
    }

    /// Build SwiftUI Path with a translation offset
    private func buildPath(offsetX: CGFloat, offsetY: CGFloat) -> Path {
        Path { p in
            guard !path.points.isEmpty else { return }

            let first = path.points[0]
            p.move(to: CGPoint(x: first.position.x + offsetX, y: first.position.y + offsetY))

            for i in 1..<path.points.count {
                addSegment(to: &p, from: path.points[i - 1], to: path.points[i], ox: offsetX, oy: offsetY)
            }

            if path.isClosed && path.points.count > 1 {
                addSegment(to: &p, from: path.points.last!, to: path.points[0], ox: offsetX, oy: offsetY)
                p.closeSubpath()
            }
        }
    }

    private func addSegment(to p: inout Path, from prev: PathPoint, to curr: PathPoint, ox: CGFloat, oy: CGFloat) {
        let currPos = CGPoint(x: curr.position.x + ox, y: curr.position.y + oy)
        let hasOut = prev.handleOut != nil
        let hasIn = curr.handleIn != nil

        if hasOut && hasIn {
            let c1 = CGPoint(x: prev.handleOutAbsolute!.x + ox, y: prev.handleOutAbsolute!.y + oy)
            let c2 = CGPoint(x: curr.handleInAbsolute!.x + ox, y: curr.handleInAbsolute!.y + oy)
            p.addCurve(to: currPos, control1: c1, control2: c2)
        } else if hasOut {
            let c = CGPoint(x: prev.handleOutAbsolute!.x + ox, y: prev.handleOutAbsolute!.y + oy)
            p.addQuadCurve(to: currPos, control: c)
        } else if hasIn {
            let c = CGPoint(x: curr.handleInAbsolute!.x + ox, y: curr.handleInAbsolute!.y + oy)
            p.addQuadCurve(to: currPos, control: c)
        } else {
            p.addLine(to: currPos)
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
