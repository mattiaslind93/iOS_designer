import SwiftUI
import DesignModel

/// Overlay shown when editing a vector path.
/// Uses a single gesture on the whole area with manual hit-testing to determine
/// which point or handle the user is interacting with.
///
/// Interactions:
/// - Click point → select it
/// - Drag point → move it
/// - Drag handle → adjust bezier curve (mirrors by default, Option breaks symmetry)
/// - Click empty area (open path) → add corner point
/// - Click+drag empty area → add point with bezier handles
/// - Click near segment (closed path) → insert point on segment
/// - Delete key → remove selected point
public struct PathEditingOverlay: View {
    let elementID: UUID
    @ObservedObject var document: DesignDocument
    @Binding var selectedPointID: UUID?
    @Binding var isEditingPath: Bool
    let frameSize: CGSize

    // What we're currently dragging
    @State private var dragTarget: DragTarget? = nil
    @State private var dragStartPosition: CGPoint = .zero  // original position before drag
    @State private var dragStartHandle: CGPoint = .zero     // original handle offset before drag
    @State private var isDragging: Bool = false

    // For creating new points via drag
    @State private var newPointID: UUID? = nil

    private let pointSize: CGFloat = 10
    private let handleSize: CGFloat = 8
    private let hitRadius: CGFloat = 12

    private enum DragTarget: Equatable {
        case point(UUID)
        case handleIn(UUID)
        case handleOut(UUID)
        case newPoint(UUID)
    }

    public init(
        elementID: UUID,
        document: DesignDocument,
        selectedPointID: Binding<UUID?>,
        isEditingPath: Binding<Bool>,
        frameSize: CGSize
    ) {
        self.elementID = elementID
        self.document = document
        self._selectedPointID = selectedPointID
        self._isEditingPath = isEditingPath
        self.frameSize = frameSize
    }

    // MARK: - Data Access

    private var vectorPath: VectorPath? {
        guard let element = findElement() else { return nil }
        if case .vectorPath(let path, _, _) = element.payload {
            return path
        }
        return nil
    }

    private func findElement() -> ElementNode? {
        guard let pageID = document.selectedPageID,
              let page = document.pages.first(where: { $0.id == pageID }) else { return nil }
        return page.rootElement.find(by: elementID)
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            guard let path = vectorPath else { return }
            drawPathOutline(context: context, path: path, size: size)
            drawHandles(context: context, path: path)
            drawPoints(context: context, path: path)
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        // First movement — determine what we hit
                        beginDrag(at: value.startLocation)
                        isDragging = true
                    }
                    continueDrag(to: value.location, translation: value.translation)
                }
                .onEnded { value in
                    let dist = hypot(value.translation.width, value.translation.height)
                    if dist < 3 && dragTarget == nil {
                        // Tap on empty area
                        handleTap(at: value.startLocation)
                    }
                    endDrag()
                }
        )
    }

    // MARK: - Drawing

    private func drawPathOutline(context: GraphicsContext, path vectorPath: VectorPath, size: CGSize) {
        let swiftPath = buildSwiftUIPath(from: vectorPath)
        context.stroke(swiftPath, with: .color(.blue.opacity(0.3)), lineWidth: 1.5)
    }

    private func drawPoints(context: GraphicsContext, path: VectorPath) {
        for point in path.points {
            let isSelected = point.id == selectedPointID
            let pos = point.position
            let size = pointSize

            let rect = CGRect(
                x: pos.x - size / 2,
                y: pos.y - size / 2,
                width: size,
                height: size
            )

            if point.isCurve {
                // Circle for curve points
                let circle = Path(ellipseIn: rect)
                context.fill(circle, with: .color(isSelected ? .blue : .white))
                context.stroke(circle, with: .color(.blue), lineWidth: 1.5)
            } else {
                // Square for corner points
                let square = Path(rect)
                context.fill(square, with: .color(isSelected ? .blue : .white))
                context.stroke(square, with: .color(.blue), lineWidth: 1.5)
            }
        }
    }

    private func drawHandles(context: GraphicsContext, path: VectorPath) {
        for point in path.points {
            guard point.id == selectedPointID else { continue }
            let pos = point.position

            // Handle In
            if let absIn = point.handleInAbsolute {
                // Line from point to handle
                var line = Path()
                line.move(to: pos)
                line.addLine(to: absIn)
                context.stroke(line, with: .color(.blue.opacity(0.5)), lineWidth: 1)

                // Handle dot
                let handleRect = CGRect(
                    x: absIn.x - handleSize / 2,
                    y: absIn.y - handleSize / 2,
                    width: handleSize,
                    height: handleSize
                )
                let dot = Path(ellipseIn: handleRect)
                context.fill(dot, with: .color(.orange))
                context.stroke(dot, with: .color(.white), lineWidth: 1)
            }

            // Handle Out
            if let absOut = point.handleOutAbsolute {
                var line = Path()
                line.move(to: pos)
                line.addLine(to: absOut)
                context.stroke(line, with: .color(.blue.opacity(0.5)), lineWidth: 1)

                let handleRect = CGRect(
                    x: absOut.x - handleSize / 2,
                    y: absOut.y - handleSize / 2,
                    width: handleSize,
                    height: handleSize
                )
                let dot = Path(ellipseIn: handleRect)
                context.fill(dot, with: .color(.orange))
                context.stroke(dot, with: .color(.white), lineWidth: 1)
            }
        }
    }

    // MARK: - Hit Testing

    /// Find what the user tapped/clicked on
    private func hitTest(at location: CGPoint) -> DragTarget? {
        guard let path = vectorPath else { return nil }

        // First check handles of selected point (highest priority, they're on top)
        if let selectedID = selectedPointID,
           let selectedPoint = path.points.first(where: { $0.id == selectedID }) {
            if let absOut = selectedPoint.handleOutAbsolute {
                if distance(location, absOut) < hitRadius {
                    return .handleOut(selectedID)
                }
            }
            if let absIn = selectedPoint.handleInAbsolute {
                if distance(location, absIn) < hitRadius {
                    return .handleIn(selectedID)
                }
            }
        }

        // Then check all anchor points
        for point in path.points.reversed() { // reversed so topmost (last drawn) is checked first
            if distance(location, point.position) < hitRadius {
                return .point(point.id)
            }
        }

        return nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Drag Logic

    private func beginDrag(at location: CGPoint) {
        guard let target = hitTest(at: location) else {
            // Hit nothing — might be creating a new point (handled in continueDrag/endDrag)
            dragTarget = nil
            return
        }

        dragTarget = target
        guard let path = vectorPath else { return }

        switch target {
        case .point(let id):
            selectedPointID = id
            if let point = path.points.first(where: { $0.id == id }) {
                dragStartPosition = point.position
            }
        case .handleIn(let id):
            if let point = path.points.first(where: { $0.id == id }) {
                dragStartHandle = point.handleIn ?? .zero
            }
        case .handleOut(let id):
            if let point = path.points.first(where: { $0.id == id }) {
                dragStartHandle = point.handleOut ?? .zero
            }
        case .newPoint:
            break
        }
    }

    private func continueDrag(to location: CGPoint, translation: CGSize) {
        guard let target = dragTarget else {
            // No target — if dragging far enough on empty area, create bezier point
            let dist = hypot(translation.width, translation.height)
            if dist > 5 && newPointID == nil {
                startNewBezierPoint(at: CGPoint(
                    x: location.x - translation.width,
                    y: location.y - translation.height
                ))
                if let id = newPointID {
                    dragTarget = .newPoint(id)
                }
            }
            if let id = newPointID {
                updateNewPointHandles(id: id, translation: translation)
            }
            return
        }

        switch target {
        case .point(let id):
            // Move point: set absolute position = startPosition + translation
            let newPos = CGPoint(
                x: dragStartPosition.x + translation.width,
                y: dragStartPosition.y + translation.height
            )
            document.updateElement(elementID) { node in
                if case .vectorPath(var path, let stroke, let fill) = node.payload {
                    if let idx = path.points.firstIndex(where: { $0.id == id }) {
                        path.points[idx].position = newPos
                    }
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                }
            }

        case .handleIn(let id):
            let newHandle = CGPoint(
                x: dragStartHandle.x + translation.width,
                y: dragStartHandle.y + translation.height
            )
            document.updateElement(elementID) { node in
                if case .vectorPath(var path, let stroke, let fill) = node.payload {
                    if let idx = path.points.firstIndex(where: { $0.id == id }) {
                        path.points[idx].handleIn = newHandle
                        // Mirror to handleOut for smooth curves (unless Option held)
                        if !NSEvent.modifierFlags.contains(.option) {
                            path.points[idx].handleOut = CGPoint(x: -newHandle.x, y: -newHandle.y)
                        }
                    }
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                }
            }

        case .handleOut(let id):
            let newHandle = CGPoint(
                x: dragStartHandle.x + translation.width,
                y: dragStartHandle.y + translation.height
            )
            document.updateElement(elementID) { node in
                if case .vectorPath(var path, let stroke, let fill) = node.payload {
                    if let idx = path.points.firstIndex(where: { $0.id == id }) {
                        path.points[idx].handleOut = newHandle
                        if !NSEvent.modifierFlags.contains(.option) {
                            path.points[idx].handleIn = CGPoint(x: -newHandle.x, y: -newHandle.y)
                        }
                    }
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                }
            }

        case .newPoint(let id):
            updateNewPointHandles(id: id, translation: translation)
        }
    }

    private func endDrag() {
        dragTarget = nil
        isDragging = false
        newPointID = nil
    }

    // MARK: - Tap on Empty Area

    private func handleTap(at location: CGPoint) {
        // Check if we tapped a point first
        if let target = hitTest(at: location) {
            if case .point(let id) = target {
                selectedPointID = id
                return
            }
        }

        guard let path = vectorPath else { return }

        if !path.isClosed || path.points.isEmpty {
            // Open path: add corner point
            let newPoint = PathPoint(position: location)
            document.updateElement(elementID) { node in
                if case .vectorPath(var p, let stroke, let fill) = node.payload {
                    p.points.append(newPoint)
                    node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
                }
            }
            selectedPointID = newPoint.id
        } else {
            // Closed path: insert on nearest segment
            insertPointOnNearestSegment(at: location)
        }
    }

    // MARK: - New Bezier Point (drag to set handles)

    private func startNewBezierPoint(at location: CGPoint) {
        guard let path = vectorPath else { return }
        guard !path.isClosed || path.points.isEmpty else { return }

        let id = UUID()
        newPointID = id
        let newPoint = PathPoint(
            id: id,
            position: location,
            handleIn: .zero,
            handleOut: .zero
        )
        document.updateElement(elementID) { node in
            if case .vectorPath(var p, let stroke, let fill) = node.payload {
                p.points.append(newPoint)
                node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
            }
        }
        selectedPointID = id
    }

    private func updateNewPointHandles(id: UUID, translation: CGSize) {
        document.updateElement(elementID) { node in
            if case .vectorPath(var path, let stroke, let fill) = node.payload {
                if let idx = path.points.firstIndex(where: { $0.id == id }) {
                    let handleOut = CGPoint(x: translation.width, y: translation.height)
                    let handleIn = CGPoint(x: -translation.width, y: -translation.height)
                    path.points[idx].handleOut = handleOut
                    path.points[idx].handleIn = handleIn
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                }
            }
        }
    }

    // MARK: - Insert Point on Segment

    private func insertPointOnNearestSegment(at point: CGPoint) {
        guard let path = vectorPath, path.points.count >= 2 else { return }

        var bestDist: CGFloat = .infinity
        var bestIndex: Int = 0
        var bestT: CGFloat = 0.5

        let count = path.isClosed ? path.points.count : path.points.count - 1
        for i in 0..<count {
            let p0 = path.points[i]
            let p1 = path.points[(i + 1) % path.points.count]
            let (dist, t) = distanceToSegment(point: point, from: p0.position, to: p1.position)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i + 1
                bestT = t
            }
        }

        guard bestDist < 30 else {
            selectedPointID = nil
            return
        }

        let p0 = path.points[bestIndex - 1]
        let p1 = path.points[bestIndex % path.points.count]
        let newPos = CGPoint(
            x: p0.position.x + (p1.position.x - p0.position.x) * bestT,
            y: p0.position.y + (p1.position.y - p0.position.y) * bestT
        )

        let newPoint = PathPoint(position: newPos)
        document.updateElement(elementID) { node in
            if case .vectorPath(var p, let stroke, let fill) = node.payload {
                p.points.insert(newPoint, at: bestIndex)
                node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
            }
        }
        selectedPointID = newPoint.id
    }

    private func distanceToSegment(point: CGPoint, from: CGPoint, to: CGPoint) -> (CGFloat, CGFloat) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else {
            return (hypot(point.x - from.x, point.y - from.y), 0)
        }
        var t = ((point.x - from.x) * dx + (point.y - from.y) * dy) / lenSq
        t = max(0, min(1, t))
        let proj = CGPoint(x: from.x + t * dx, y: from.y + t * dy)
        return (hypot(point.x - proj.x, point.y - proj.y), t)
    }

    // MARK: - Build SwiftUI Path (for outline drawing)

    private func buildSwiftUIPath(from vectorPath: VectorPath) -> Path {
        Path { p in
            guard !vectorPath.points.isEmpty else { return }
            p.move(to: vectorPath.points[0].position)

            for i in 1..<vectorPath.points.count {
                let prev = vectorPath.points[i - 1]
                let curr = vectorPath.points[i]
                addSegment(to: &p, from: prev, to: curr)
            }

            if vectorPath.isClosed && vectorPath.points.count > 1 {
                let last = vectorPath.points[vectorPath.points.count - 1]
                let first = vectorPath.points[0]
                addSegment(to: &p, from: last, to: first)
                p.closeSubpath()
            }
        }
    }

    private func addSegment(to p: inout Path, from prev: PathPoint, to curr: PathPoint) {
        let hasOut = prev.handleOut != nil
        let hasIn = curr.handleIn != nil

        if hasOut && hasIn {
            p.addCurve(to: curr.position, control1: prev.handleOutAbsolute!, control2: curr.handleInAbsolute!)
        } else if hasOut {
            p.addQuadCurve(to: curr.position, control: prev.handleOutAbsolute!)
        } else if hasIn {
            p.addQuadCurve(to: curr.position, control: curr.handleInAbsolute!)
        } else {
            p.addLine(to: curr.position)
        }
    }
}
