import Foundation
import CoreGraphics

// MARK: - Vector Path

/// A complete vector path made up of ordered segments.
/// Supports open/closed paths and both straight lines and cubic bezier curves.
public struct VectorPath: Codable, Hashable {
    public var points: [PathPoint]
    public var isClosed: Bool
    public var fillRule: FillRuleType

    public init(points: [PathPoint] = [], isClosed: Bool = true, fillRule: FillRuleType = .evenOdd) {
        self.points = points
        self.isClosed = isClosed
        self.fillRule = fillRule
    }
}

/// A single anchor point in a vector path, with optional bezier control handles.
/// Control handles are stored as RELATIVE offsets from the anchor point.
public struct PathPoint: Codable, Hashable, Identifiable {
    public let id: UUID
    public var position: CGPoint
    /// Incoming bezier handle — relative offset from position
    public var handleIn: CGPoint?
    /// Outgoing bezier handle — relative offset from position
    public var handleOut: CGPoint?

    public init(id: UUID = UUID(), position: CGPoint, handleIn: CGPoint? = nil, handleOut: CGPoint? = nil) {
        self.id = id
        self.position = position
        self.handleIn = handleIn
        self.handleOut = handleOut
    }

    /// Absolute position of the incoming handle
    public var handleInAbsolute: CGPoint? {
        guard let h = handleIn else { return nil }
        return CGPoint(x: position.x + h.x, y: position.y + h.y)
    }

    /// Absolute position of the outgoing handle
    public var handleOutAbsolute: CGPoint? {
        guard let h = handleOut else { return nil }
        return CGPoint(x: position.x + h.x, y: position.y + h.y)
    }

    /// Whether this point has bezier handles (curve) vs a corner (straight)
    public var isCurve: Bool {
        handleIn != nil || handleOut != nil
    }
}

public enum FillRuleType: String, Codable, Hashable, CaseIterable {
    case evenOdd, winding
}

// MARK: - Stroke Style

public struct VectorStrokeStyle: Codable, Hashable {
    public var color: DesignColor
    public var width: CGFloat
    public var lineCap: LineCapType
    public var lineJoin: LineJoinType
    public var miterLimit: CGFloat
    public var dashPattern: [CGFloat]

    public init(
        color: DesignColor = .black,
        width: CGFloat = 2,
        lineCap: LineCapType = .round,
        lineJoin: LineJoinType = .round,
        miterLimit: CGFloat = 10,
        dashPattern: [CGFloat] = []
    ) {
        self.color = color
        self.width = width
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.dashPattern = dashPattern
    }

    public static let `default` = VectorStrokeStyle()
}

public enum LineCapType: String, Codable, Hashable, CaseIterable {
    case butt, round, square
}

public enum LineJoinType: String, Codable, Hashable, CaseIterable {
    case miter, round, bevel
}

// MARK: - Shape Presets

/// Factory for creating VectorPath instances from preset geometric shapes.
public enum VectorShapePreset: String, Codable, Hashable, CaseIterable {
    case square, circle, triangle, star, pentagon, hexagon, arrow, heart

    public var displayName: String {
        rawValue.capitalized
    }

    public var icon: String {
        switch self {
        case .square:   return "square"
        case .circle:   return "circle"
        case .triangle: return "triangle"
        case .star:     return "star"
        case .pentagon: return "pentagon"
        case .hexagon:  return "hexagon"
        case .arrow:    return "arrowshape.right"
        case .heart:    return "heart"
        }
    }

    /// Create a VectorPath for this shape preset within the given rect.
    public func makePath(in rect: CGRect) -> VectorPath {
        switch self {
        case .square:   return makeSquare(rect)
        case .circle:   return makeCircle(rect)
        case .triangle: return makeTriangle(rect)
        case .star:     return makeStar(rect)
        case .pentagon: return makePolygon(rect, sides: 5)
        case .hexagon:  return makePolygon(rect, sides: 6)
        case .arrow:    return makeArrow(rect)
        case .heart:    return makeHeart(rect)
        }
    }

    // MARK: - Shape Generators

    private func makeSquare(_ r: CGRect) -> VectorPath {
        VectorPath(points: [
            PathPoint(position: CGPoint(x: r.minX, y: r.minY)),
            PathPoint(position: CGPoint(x: r.maxX, y: r.minY)),
            PathPoint(position: CGPoint(x: r.maxX, y: r.maxY)),
            PathPoint(position: CGPoint(x: r.minX, y: r.maxY)),
        ], isClosed: true)
    }

    private func makeCircle(_ r: CGRect) -> VectorPath {
        // Approximate circle with 4 cubic bezier segments
        // Magic number: handle length = radius * 0.5522847
        let cx = r.midX, cy = r.midY
        let rx = r.width / 2, ry = r.height / 2
        let kx = rx * 0.5522847, ky = ry * 0.5522847
        return VectorPath(points: [
            PathPoint(position: CGPoint(x: cx, y: r.minY),
                     handleIn: CGPoint(x: kx, y: 0),
                     handleOut: CGPoint(x: -kx, y: 0)),
            PathPoint(position: CGPoint(x: r.minX, y: cy),
                     handleIn: CGPoint(x: 0, y: -ky),
                     handleOut: CGPoint(x: 0, y: ky)),
            PathPoint(position: CGPoint(x: cx, y: r.maxY),
                     handleIn: CGPoint(x: -kx, y: 0),
                     handleOut: CGPoint(x: kx, y: 0)),
            PathPoint(position: CGPoint(x: r.maxX, y: cy),
                     handleIn: CGPoint(x: 0, y: ky),
                     handleOut: CGPoint(x: 0, y: -ky)),
        ], isClosed: true)
    }

    private func makeTriangle(_ r: CGRect) -> VectorPath {
        VectorPath(points: [
            PathPoint(position: CGPoint(x: r.midX, y: r.minY)),
            PathPoint(position: CGPoint(x: r.maxX, y: r.maxY)),
            PathPoint(position: CGPoint(x: r.minX, y: r.maxY)),
        ], isClosed: true)
    }

    private func makePolygon(_ r: CGRect, sides: Int) -> VectorPath {
        let cx = r.midX, cy = r.midY
        let rx = r.width / 2, ry = r.height / 2
        var points: [PathPoint] = []
        for i in 0..<sides {
            let angle = (CGFloat(i) / CGFloat(sides)) * 2 * .pi - .pi / 2
            points.append(PathPoint(position: CGPoint(
                x: cx + rx * cos(angle),
                y: cy + ry * sin(angle)
            )))
        }
        return VectorPath(points: points, isClosed: true)
    }

    private func makeStar(_ r: CGRect) -> VectorPath {
        let cx = r.midX, cy = r.midY
        let outerRx = r.width / 2, outerRy = r.height / 2
        let innerRx = outerRx * 0.38, innerRy = outerRy * 0.38
        var points: [PathPoint] = []
        for i in 0..<10 {
            let angle = (CGFloat(i) / 10) * 2 * .pi - .pi / 2
            let isOuter = i % 2 == 0
            let rx = isOuter ? outerRx : innerRx
            let ry = isOuter ? outerRy : innerRy
            points.append(PathPoint(position: CGPoint(
                x: cx + rx * cos(angle),
                y: cy + ry * sin(angle)
            )))
        }
        return VectorPath(points: points, isClosed: true)
    }

    private func makeArrow(_ r: CGRect) -> VectorPath {
        let w = r.width, h = r.height
        let x = r.minX, y = r.minY
        return VectorPath(points: [
            PathPoint(position: CGPoint(x: x, y: y + h * 0.3)),
            PathPoint(position: CGPoint(x: x + w * 0.6, y: y + h * 0.3)),
            PathPoint(position: CGPoint(x: x + w * 0.6, y: y)),
            PathPoint(position: CGPoint(x: x + w, y: y + h * 0.5)),
            PathPoint(position: CGPoint(x: x + w * 0.6, y: y + h)),
            PathPoint(position: CGPoint(x: x + w * 0.6, y: y + h * 0.7)),
            PathPoint(position: CGPoint(x: x, y: y + h * 0.7)),
        ], isClosed: true)
    }

    private func makeHeart(_ r: CGRect) -> VectorPath {
        let w = r.width, h = r.height
        let x = r.minX, y = r.minY
        return VectorPath(points: [
            PathPoint(position: CGPoint(x: x + w * 0.5, y: y + h * 0.25),
                     handleIn: CGPoint(x: w * 0.15, y: -h * 0.15),
                     handleOut: CGPoint(x: -w * 0.15, y: -h * 0.15)),
            PathPoint(position: CGPoint(x: x + w * 0.15, y: y + h * 0.1),
                     handleIn: CGPoint(x: w * 0.15, y: 0),
                     handleOut: CGPoint(x: -w * 0.12, y: 0)),
            PathPoint(position: CGPoint(x: x, y: y + h * 0.35),
                     handleIn: CGPoint(x: 0, y: -h * 0.15),
                     handleOut: CGPoint(x: 0, y: h * 0.15)),
            PathPoint(position: CGPoint(x: x + w * 0.5, y: y + h),
                     handleIn: CGPoint(x: -w * 0.3, y: -h * 0.15),
                     handleOut: CGPoint(x: w * 0.3, y: -h * 0.15)),
            PathPoint(position: CGPoint(x: x + w, y: y + h * 0.35),
                     handleIn: CGPoint(x: 0, y: h * 0.15),
                     handleOut: CGPoint(x: 0, y: -h * 0.15)),
            PathPoint(position: CGPoint(x: x + w * 0.85, y: y + h * 0.1),
                     handleIn: CGPoint(x: w * 0.12, y: 0),
                     handleOut: CGPoint(x: -w * 0.15, y: 0)),
        ], isClosed: true)
    }
}

// MARK: - Imported Image

/// Image data stored inline in the document for portability.
public struct ImportedImageData: Codable, Hashable {
    public let id: UUID
    public var fileName: String
    public var imageData: Data
    public var originalSize: CGSize
    public var contentMode: ImageContentMode

    public init(
        id: UUID = UUID(),
        fileName: String,
        imageData: Data,
        originalSize: CGSize,
        contentMode: ImageContentMode = .fit
    ) {
        self.id = id
        self.fileName = fileName
        self.imageData = imageData
        self.originalSize = originalSize
        self.contentMode = contentMode
    }
}

public enum ImageContentMode: String, Codable, Hashable, CaseIterable {
    case fit, fill, stretch
}
