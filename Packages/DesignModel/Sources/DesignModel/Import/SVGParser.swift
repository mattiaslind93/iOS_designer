import Foundation
import CoreGraphics

/// Parses SVG files into VectorPath elements.
/// Supports basic SVG shapes (<path>, <rect>, <circle>, <ellipse>, <line>, <polygon>, <polyline>)
/// and the SVG path `d` attribute command set (M, L, H, V, C, S, Q, T, A, Z).
public struct SVGParser {

    public init() {}

    /// Parse an SVG file from data and return element nodes.
    /// Each SVG shape becomes a separate ElementNode with a vectorPath payload.
    public func parse(data: Data, fileName: String) -> [ElementNode] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        return parse(svgString: content, fileName: fileName)
    }

    /// Parse an SVG string and return element nodes.
    public func parse(svgString: String, fileName: String) -> [ElementNode] {
        let delegate = SVGXMLDelegate()
        let xmlParser = XMLParser(data: Data(svgString.utf8))
        xmlParser.delegate = delegate
        xmlParser.parse()
        return delegate.elements
    }

    /// Parse just an SVG path `d` attribute string into a VectorPath.
    public static func parsePath(d: String) -> VectorPath {
        var parser = SVGPathDParser(d: d)
        return parser.parse()
    }
}

// MARK: - XML Delegate

private class SVGXMLDelegate: NSObject, XMLParserDelegate {
    var elements: [ElementNode] = []
    private var viewBoxTransform: CGAffineTransform = .identity
    private var viewBoxSize: CGSize = CGSize(width: 100, height: 100)

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {

        switch elementName.lowercased() {
        case "svg":
            parseViewBox(attributes)

        case "path":
            if let d = attributes["d"] {
                let path = SVGParser.parsePath(d: d)
                let stroke = parseStroke(attributes)
                let fill = parseFill(attributes)
                let name = attributes["id"] ?? "Path"
                let node = ElementNode(
                    name: name,
                    payload: .vectorPath(path: path, stroke: stroke, fill: fill)
                )
                elements.append(node)
            }

        case "rect":
            if let node = parseRect(attributes) {
                elements.append(node)
            }

        case "circle":
            if let node = parseCircle(attributes) {
                elements.append(node)
            }

        case "ellipse":
            if let node = parseEllipse(attributes) {
                elements.append(node)
            }

        case "line":
            if let node = parseLine(attributes) {
                elements.append(node)
            }

        case "polygon":
            if let node = parsePolygon(attributes, closed: true) {
                elements.append(node)
            }

        case "polyline":
            if let node = parsePolygon(attributes, closed: false) {
                elements.append(node)
            }

        default:
            break
        }
    }

    // MARK: - ViewBox

    private func parseViewBox(_ attrs: [String: String]) {
        if let vb = attrs["viewBox"] {
            let parts = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if parts.count == 4 {
                viewBoxSize = CGSize(width: parts[2], height: parts[3])
            }
        } else {
            let w = Double(attrs["width"] ?? "100") ?? 100
            let h = Double(attrs["height"] ?? "100") ?? 100
            viewBoxSize = CGSize(width: w, height: h)
        }
    }

    // MARK: - Shape Parsers

    private func parseRect(_ attrs: [String: String]) -> ElementNode? {
        let x = cgFloat(attrs["x"]) ?? 0
        let y = cgFloat(attrs["y"]) ?? 0
        let w = cgFloat(attrs["width"]) ?? 0
        let h = cgFloat(attrs["height"]) ?? 0
        guard w > 0 && h > 0 else { return nil }

        let rx = cgFloat(attrs["rx"]) ?? 0
        let ry = cgFloat(attrs["ry"]) ?? rx

        let path: VectorPath
        if rx > 0 || ry > 0 {
            path = makeRoundedRect(x: x, y: y, w: w, h: h, rx: rx, ry: ry)
        } else {
            path = VectorPath(points: [
                PathPoint(position: CGPoint(x: x, y: y)),
                PathPoint(position: CGPoint(x: x + w, y: y)),
                PathPoint(position: CGPoint(x: x + w, y: y + h)),
                PathPoint(position: CGPoint(x: x, y: y + h)),
            ], isClosed: true)
        }

        let name = attrs["id"] ?? "Rectangle"
        return ElementNode(
            name: name,
            payload: .vectorPath(path: path, stroke: parseStroke(attrs), fill: parseFill(attrs))
        )
    }

    private func parseCircle(_ attrs: [String: String]) -> ElementNode? {
        let cx = cgFloat(attrs["cx"]) ?? 0
        let cy = cgFloat(attrs["cy"]) ?? 0
        let r = cgFloat(attrs["r"]) ?? 0
        guard r > 0 else { return nil }

        let path = makeEllipsePath(cx: cx, cy: cy, rx: r, ry: r)
        let name = attrs["id"] ?? "Circle"
        return ElementNode(
            name: name,
            payload: .vectorPath(path: path, stroke: parseStroke(attrs), fill: parseFill(attrs))
        )
    }

    private func parseEllipse(_ attrs: [String: String]) -> ElementNode? {
        let cx = cgFloat(attrs["cx"]) ?? 0
        let cy = cgFloat(attrs["cy"]) ?? 0
        let rx = cgFloat(attrs["rx"]) ?? 0
        let ry = cgFloat(attrs["ry"]) ?? 0
        guard rx > 0 && ry > 0 else { return nil }

        let path = makeEllipsePath(cx: cx, cy: cy, rx: rx, ry: ry)
        let name = attrs["id"] ?? "Ellipse"
        return ElementNode(
            name: name,
            payload: .vectorPath(path: path, stroke: parseStroke(attrs), fill: parseFill(attrs))
        )
    }

    private func parseLine(_ attrs: [String: String]) -> ElementNode? {
        let x1 = cgFloat(attrs["x1"]) ?? 0
        let y1 = cgFloat(attrs["y1"]) ?? 0
        let x2 = cgFloat(attrs["x2"]) ?? 0
        let y2 = cgFloat(attrs["y2"]) ?? 0

        let path = VectorPath(points: [
            PathPoint(position: CGPoint(x: x1, y: y1)),
            PathPoint(position: CGPoint(x: x2, y: y2)),
        ], isClosed: false)

        let name = attrs["id"] ?? "Line"
        return ElementNode(
            name: name,
            payload: .vectorPath(path: path, stroke: parseStroke(attrs), fill: nil)
        )
    }

    private func parsePolygon(_ attrs: [String: String], closed: Bool) -> ElementNode? {
        guard let pointsStr = attrs["points"] else { return nil }
        let numbers = pointsStr.split(whereSeparator: { $0 == " " || $0 == "," })
            .compactMap { Double($0) }
        guard numbers.count >= 4 && numbers.count % 2 == 0 else { return nil }

        var points: [PathPoint] = []
        for i in stride(from: 0, to: numbers.count, by: 2) {
            points.append(PathPoint(position: CGPoint(x: numbers[i], y: numbers[i + 1])))
        }

        let path = VectorPath(points: points, isClosed: closed)
        let name = attrs["id"] ?? (closed ? "Polygon" : "Polyline")
        return ElementNode(
            name: name,
            payload: .vectorPath(path: path, stroke: parseStroke(attrs), fill: parseFill(attrs))
        )
    }

    // MARK: - Style Parsing

    private func parseStroke(_ attrs: [String: String]) -> VectorStrokeStyle? {
        let color = parseColor(attrs["stroke"])
        guard let color else { return nil }
        let width = cgFloat(attrs["stroke-width"]) ?? 1
        return VectorStrokeStyle(color: color, width: width)
    }

    private func parseFill(_ attrs: [String: String]) -> DesignColor? {
        if attrs["fill"] == "none" { return nil }
        return parseColor(attrs["fill"])
    }

    private func parseColor(_ value: String?) -> DesignColor? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if value == "none" { return nil }
        if value == "black" { return .custom(red: 0, green: 0, blue: 0, opacity: 1) }
        if value == "white" { return .custom(red: 1, green: 1, blue: 1, opacity: 1) }
        if value == "red" { return .system(.red) }
        if value == "green" { return .system(.green) }
        if value == "blue" { return .system(.blue) }
        if value == "orange" { return .system(.orange) }
        if value == "yellow" { return .system(.yellow) }
        if value == "purple" { return .system(.purple) }
        if value == "gray" || value == "grey" { return .system(.gray) }

        // Hex color: #RRGGBB or #RGB
        if value.hasPrefix("#") {
            return parseHexColor(String(value.dropFirst()))
        }

        // rgb(r, g, b)
        if value.hasPrefix("rgb(") {
            let inner = value.dropFirst(4).dropLast()
            let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 3,
               let r = Double(parts[0]),
               let g = Double(parts[1]),
               let b = Double(parts[2]) {
                return .custom(red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
            }
        }

        return .custom(red: 0, green: 0, blue: 0, opacity: 1) // default black
    }

    private func parseHexColor(_ hex: String) -> DesignColor {
        var hexStr = hex
        if hexStr.count == 3 {
            hexStr = hexStr.map { "\($0)\($0)" }.joined()
        }
        guard hexStr.count == 6,
              let val = UInt64(hexStr, radix: 16) else {
            return .custom(red: 0, green: 0, blue: 0, opacity: 1)
        }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return .custom(red: r, green: g, blue: b, opacity: 1)
    }

    // MARK: - Shape Helpers

    private func makeEllipsePath(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> VectorPath {
        let kx = rx * 0.5522847
        let ky = ry * 0.5522847
        return VectorPath(points: [
            PathPoint(position: CGPoint(x: cx, y: cy - ry),
                     handleIn: CGPoint(x: kx, y: 0),
                     handleOut: CGPoint(x: -kx, y: 0)),
            PathPoint(position: CGPoint(x: cx - rx, y: cy),
                     handleIn: CGPoint(x: 0, y: -ky),
                     handleOut: CGPoint(x: 0, y: ky)),
            PathPoint(position: CGPoint(x: cx, y: cy + ry),
                     handleIn: CGPoint(x: -kx, y: 0),
                     handleOut: CGPoint(x: kx, y: 0)),
            PathPoint(position: CGPoint(x: cx + rx, y: cy),
                     handleIn: CGPoint(x: 0, y: ky),
                     handleOut: CGPoint(x: 0, y: -ky)),
        ], isClosed: true)
    }

    private func makeRoundedRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                  rx: CGFloat, ry: CGFloat) -> VectorPath {
        let kx = rx * 0.5522847
        let ky = ry * 0.5522847
        return VectorPath(points: [
            // Top-left corner
            PathPoint(position: CGPoint(x: x + rx, y: y),
                     handleIn: CGPoint(x: -kx, y: 0), handleOut: nil),
            // Top-right corner
            PathPoint(position: CGPoint(x: x + w - rx, y: y),
                     handleIn: nil, handleOut: CGPoint(x: kx, y: 0)),
            PathPoint(position: CGPoint(x: x + w, y: y + ry),
                     handleIn: CGPoint(x: 0, y: -ky), handleOut: nil),
            // Bottom-right corner
            PathPoint(position: CGPoint(x: x + w, y: y + h - ry),
                     handleIn: nil, handleOut: CGPoint(x: 0, y: ky)),
            PathPoint(position: CGPoint(x: x + w - rx, y: y + h),
                     handleIn: CGPoint(x: kx, y: 0), handleOut: nil),
            // Bottom-left corner
            PathPoint(position: CGPoint(x: x + rx, y: y + h),
                     handleIn: nil, handleOut: CGPoint(x: -kx, y: 0)),
            PathPoint(position: CGPoint(x: x, y: y + h - ry),
                     handleIn: CGPoint(x: 0, y: ky), handleOut: nil),
            // Close to top-left
            PathPoint(position: CGPoint(x: x, y: y + ry),
                     handleIn: nil, handleOut: CGPoint(x: 0, y: -ky)),
        ], isClosed: true)
    }

    private func cgFloat(_ s: String?) -> CGFloat? {
        guard let s else { return nil }
        // Remove "px" suffix if present
        let cleaned = s.replacingOccurrences(of: "px", with: "")
        return Double(cleaned).map { CGFloat($0) }
    }
}

// MARK: - SVG Path `d` Attribute Parser

/// Parses an SVG path data string (the `d` attribute) into a VectorPath.
/// Supports: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z
private struct SVGPathDParser {
    let d: String
    private var index: String.Index
    private var points: [PathPoint] = []
    private var currentPoint = CGPoint.zero
    private var startOfSubpath = CGPoint.zero
    private var isClosed = false
    private var lastControlPoint: CGPoint? = nil
    private var lastCommand: Character? = nil

    init(d: String) {
        self.d = d
        self.index = d.startIndex
    }

    mutating func parse() -> VectorPath {
        while index < d.endIndex {
            skipWhitespaceAndCommas()
            guard index < d.endIndex else { break }

            let ch = d[index]
            if ch.isLetter {
                index = d.index(after: index)
                processCommand(ch)
            } else {
                // Implicit repeat of last command
                if let last = lastCommand {
                    processCommand(last, isImplicit: true)
                } else {
                    index = d.index(after: index)
                }
            }
        }

        return VectorPath(points: points, isClosed: isClosed)
    }

    private mutating func processCommand(_ cmd: Character, isImplicit: Bool = false) {
        let isRelative = cmd.isLowercase
        let upper = cmd.uppercased().first!

        switch upper {
        case "M":
            let pt = readPoint(relative: isRelative)
            currentPoint = pt
            startOfSubpath = pt
            points.append(PathPoint(position: pt))
            lastCommand = isRelative ? "l" : "L" // Implicit line-to after move
            lastControlPoint = nil
            // Handle implicit line-to pairs
            while hasMoreNumbers() {
                let pt = readPoint(relative: isRelative)
                currentPoint = pt
                points.append(PathPoint(position: pt))
            }

        case "L":
            repeat {
                let pt = readPoint(relative: isRelative)
                currentPoint = pt
                points.append(PathPoint(position: pt))
                lastControlPoint = nil
            } while hasMoreNumbers()
            lastCommand = cmd

        case "H":
            repeat {
                let x = readNumber()
                let absX = isRelative ? currentPoint.x + x : x
                currentPoint = CGPoint(x: absX, y: currentPoint.y)
                points.append(PathPoint(position: currentPoint))
                lastControlPoint = nil
            } while hasMoreNumbers()
            lastCommand = cmd

        case "V":
            repeat {
                let y = readNumber()
                let absY = isRelative ? currentPoint.y + y : y
                currentPoint = CGPoint(x: currentPoint.x, y: absY)
                points.append(PathPoint(position: currentPoint))
                lastControlPoint = nil
            } while hasMoreNumbers()
            lastCommand = cmd

        case "C":
            repeat {
                let cp1 = readPoint(relative: isRelative)
                let cp2 = readPoint(relative: isRelative)
                let end = readPoint(relative: isRelative)

                // Set handleOut on previous point
                if !points.isEmpty {
                    let prevIdx = points.count - 1
                    points[prevIdx].handleOut = CGPoint(
                        x: cp1.x - points[prevIdx].position.x,
                        y: cp1.y - points[prevIdx].position.y
                    )
                }

                // Create end point with handleIn
                let handleIn = CGPoint(
                    x: cp2.x - end.x,
                    y: cp2.y - end.y
                )
                points.append(PathPoint(position: end, handleIn: handleIn))

                currentPoint = end
                lastControlPoint = cp2
            } while hasMoreNumbers()
            lastCommand = cmd

        case "S":
            repeat {
                // Smooth cubic: cp1 is reflection of last control point
                let cp1: CGPoint
                if let lcp = lastControlPoint {
                    cp1 = CGPoint(
                        x: 2 * currentPoint.x - lcp.x,
                        y: 2 * currentPoint.y - lcp.y
                    )
                } else {
                    cp1 = currentPoint
                }
                let cp2 = readPoint(relative: isRelative)
                let end = readPoint(relative: isRelative)

                if !points.isEmpty {
                    let prevIdx = points.count - 1
                    points[prevIdx].handleOut = CGPoint(
                        x: cp1.x - points[prevIdx].position.x,
                        y: cp1.y - points[prevIdx].position.y
                    )
                }

                let handleIn = CGPoint(x: cp2.x - end.x, y: cp2.y - end.y)
                points.append(PathPoint(position: end, handleIn: handleIn))

                currentPoint = end
                lastControlPoint = cp2
            } while hasMoreNumbers()
            lastCommand = cmd

        case "Q":
            repeat {
                let cp = readPoint(relative: isRelative)
                let end = readPoint(relative: isRelative)

                // Convert quadratic to approximate cubic handles
                if !points.isEmpty {
                    let prevIdx = points.count - 1
                    let p0 = points[prevIdx].position
                    let cp1 = CGPoint(
                        x: p0.x + 2.0/3.0 * (cp.x - p0.x),
                        y: p0.y + 2.0/3.0 * (cp.y - p0.y)
                    )
                    let cp2 = CGPoint(
                        x: end.x + 2.0/3.0 * (cp.x - end.x),
                        y: end.y + 2.0/3.0 * (cp.y - end.y)
                    )
                    points[prevIdx].handleOut = CGPoint(
                        x: cp1.x - p0.x, y: cp1.y - p0.y
                    )
                    points.append(PathPoint(
                        position: end,
                        handleIn: CGPoint(x: cp2.x - end.x, y: cp2.y - end.y)
                    ))
                } else {
                    points.append(PathPoint(position: end))
                }

                currentPoint = end
                lastControlPoint = cp
            } while hasMoreNumbers()
            lastCommand = cmd

        case "T":
            repeat {
                let cp: CGPoint
                if let lcp = lastControlPoint {
                    cp = CGPoint(
                        x: 2 * currentPoint.x - lcp.x,
                        y: 2 * currentPoint.y - lcp.y
                    )
                } else {
                    cp = currentPoint
                }
                let end = readPoint(relative: isRelative)

                if !points.isEmpty {
                    let prevIdx = points.count - 1
                    let p0 = points[prevIdx].position
                    let cp1 = CGPoint(
                        x: p0.x + 2.0/3.0 * (cp.x - p0.x),
                        y: p0.y + 2.0/3.0 * (cp.y - p0.y)
                    )
                    let cp2 = CGPoint(
                        x: end.x + 2.0/3.0 * (cp.x - end.x),
                        y: end.y + 2.0/3.0 * (cp.y - end.y)
                    )
                    points[prevIdx].handleOut = CGPoint(
                        x: cp1.x - p0.x, y: cp1.y - p0.y
                    )
                    points.append(PathPoint(
                        position: end,
                        handleIn: CGPoint(x: cp2.x - end.x, y: cp2.y - end.y)
                    ))
                } else {
                    points.append(PathPoint(position: end))
                }

                currentPoint = end
                lastControlPoint = cp
            } while hasMoreNumbers()
            lastCommand = cmd

        case "A":
            repeat {
                let rx = readNumber()
                let ry = readNumber()
                let xRotation = readNumber()
                let largeArc = readNumber() != 0
                let sweep = readNumber() != 0
                let end = readPoint(relative: isRelative)

                // Approximate arc with line (simple fallback)
                // A full arc-to-bezier conversion is complex but this covers most cases
                let bezierPoints = arcToBezier(
                    from: currentPoint, to: end,
                    rx: abs(rx), ry: abs(ry),
                    xRotation: xRotation, largeArc: largeArc, sweep: sweep
                )

                for bp in bezierPoints {
                    if !points.isEmpty {
                        let prevIdx = points.count - 1
                        points[prevIdx].handleOut = CGPoint(
                            x: bp.cp1.x - points[prevIdx].position.x,
                            y: bp.cp1.y - points[prevIdx].position.y
                        )
                    }
                    points.append(PathPoint(
                        position: bp.end,
                        handleIn: CGPoint(x: bp.cp2.x - bp.end.x, y: bp.cp2.y - bp.end.y)
                    ))
                }

                currentPoint = end
                lastControlPoint = nil
            } while hasMoreNumbers()
            lastCommand = cmd

        case "Z":
            isClosed = true
            currentPoint = startOfSubpath
            lastControlPoint = nil
            lastCommand = cmd

        default:
            break
        }
    }

    // MARK: - Number Parsing

    private mutating func skipWhitespaceAndCommas() {
        while index < d.endIndex && (d[index].isWhitespace || d[index] == ",") {
            index = d.index(after: index)
        }
    }

    private mutating func hasMoreNumbers() -> Bool {
        skipWhitespaceAndCommas()
        guard index < d.endIndex else { return false }
        let ch = d[index]
        return ch.isNumber || ch == "-" || ch == "+" || ch == "."
    }

    private mutating func readNumber() -> CGFloat {
        skipWhitespaceAndCommas()
        var numStr = ""
        var hasDecimal = false
        var hasE = false

        // Handle sign
        if index < d.endIndex && (d[index] == "-" || d[index] == "+") {
            numStr.append(d[index])
            index = d.index(after: index)
        }

        while index < d.endIndex {
            let ch = d[index]
            if ch.isNumber {
                numStr.append(ch)
                index = d.index(after: index)
            } else if ch == "." && !hasDecimal {
                hasDecimal = true
                numStr.append(ch)
                index = d.index(after: index)
            } else if (ch == "e" || ch == "E") && !hasE {
                hasE = true
                numStr.append(ch)
                index = d.index(after: index)
                // Handle exponent sign
                if index < d.endIndex && (d[index] == "-" || d[index] == "+") {
                    numStr.append(d[index])
                    index = d.index(after: index)
                }
            } else {
                break
            }
        }

        return CGFloat(Double(numStr) ?? 0)
    }

    private mutating func readPoint(relative: Bool) -> CGPoint {
        let x = readNumber()
        let y = readNumber()
        if relative {
            return CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Arc to Bezier Approximation

    private struct BezierSegment {
        let cp1: CGPoint
        let cp2: CGPoint
        let end: CGPoint
    }

    private func arcToBezier(from p1: CGPoint, to p2: CGPoint,
                              rx: CGFloat, ry: CGFloat,
                              xRotation: CGFloat, largeArc: Bool,
                              sweep: Bool) -> [BezierSegment] {
        // Handle degenerate cases
        guard rx > 0 && ry > 0 else {
            return [BezierSegment(cp1: p1, cp2: p2, end: p2)]
        }

        let phi = xRotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Step 1: compute (x1', y1')
        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Step 2: compute (cx', cy')
        var rxSq = rx * rx
        var rySq = ry * ry
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p

        // Correct radii
        let lambda = x1pSq / rxSq + y1pSq / rySq
        var rxAdj = rx
        var ryAdj = ry
        if lambda > 1 {
            let sqrtLambda = sqrt(lambda)
            rxAdj = sqrtLambda * rx
            ryAdj = sqrtLambda * ry
            rxSq = rxAdj * rxAdj
            rySq = ryAdj * ryAdj
        }

        let num = max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = rxSq * y1pSq + rySq * x1pSq
        let sq = den > 0 ? sqrt(num / den) : 0
        let sign: CGFloat = (largeArc == sweep) ? -1 : 1
        let cxp = sign * sq * (rxAdj * y1p / ryAdj)
        let cyp = sign * sq * -(ryAdj * x1p / rxAdj)

        // Step 3: compute (cx, cy)
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        // Step 4: compute angles
        func angle(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
            let dot = u.x * v.x + u.y * v.y
            let len = sqrt(u.x * u.x + u.y * u.y) * sqrt(v.x * v.x + v.y * v.y)
            var a = acos(max(-1, min(1, dot / len)))
            if u.x * v.y - u.y * v.x < 0 { a = -a }
            return a
        }

        let theta1 = angle(
            CGPoint(x: 1, y: 0),
            CGPoint(x: (x1p - cxp) / rxAdj, y: (y1p - cyp) / ryAdj)
        )
        var dTheta = angle(
            CGPoint(x: (x1p - cxp) / rxAdj, y: (y1p - cyp) / ryAdj),
            CGPoint(x: (-x1p - cxp) / rxAdj, y: (-y1p - cyp) / ryAdj)
        )

        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        // Split into segments of max π/2
        let segCount = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segAngle = dTheta / CGFloat(segCount)

        var result: [BezierSegment] = []
        var t1 = theta1

        for _ in 0..<segCount {
            let t2 = t1 + segAngle
            let alpha = sin(segAngle) * (sqrt(4 + 3 * pow(tan(segAngle / 2), 2)) - 1) / 3

            let cosT1 = cos(t1), sinT1 = sin(t1)
            let cosT2 = cos(t2), sinT2 = sin(t2)

            let ep1x = cosPhi * rxAdj * cosT1 - sinPhi * ryAdj * sinT1 + cx
            let ep1y = sinPhi * rxAdj * cosT1 + cosPhi * ryAdj * sinT1 + cy
            let ep2x = cosPhi * rxAdj * cosT2 - sinPhi * ryAdj * sinT2 + cx
            let ep2y = sinPhi * rxAdj * cosT2 + cosPhi * ryAdj * sinT2 + cy

            let d1x = -cosPhi * rxAdj * sinT1 - sinPhi * ryAdj * cosT1
            let d1y = -sinPhi * rxAdj * sinT1 + cosPhi * ryAdj * cosT1
            let d2x = -cosPhi * rxAdj * sinT2 - sinPhi * ryAdj * cosT2
            let d2y = -sinPhi * rxAdj * sinT2 + cosPhi * ryAdj * cosT2

            result.append(BezierSegment(
                cp1: CGPoint(x: ep1x + alpha * d1x, y: ep1y + alpha * d1y),
                cp2: CGPoint(x: ep2x - alpha * d2x, y: ep2y - alpha * d2y),
                end: CGPoint(x: ep2x, y: ep2y)
            ))

            t1 = t2
        }

        return result
    }
}
