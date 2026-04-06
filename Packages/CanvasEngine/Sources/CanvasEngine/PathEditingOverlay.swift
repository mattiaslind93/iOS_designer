import SwiftUI
import DesignModel

/// Overlay shown when editing a vector path.
/// Rendered at the phone frame level (not as element overlay) so handles
/// extending outside the element bounds are visible and interactive.
///
/// Uses a single gesture on the whole area with manual hit-testing.
public struct PathEditingOverlay: View {
    let elementID: UUID
    @ObservedObject var document: DesignDocument
    @Binding var selectedPointID: UUID?
    @Binding var selectedPointIDs: Set<UUID>
    @Binding var isEditingPath: Bool

    /// The element's offset within the phone frame (from .offset modifier)
    let elementOffset: CGPoint

    /// Snap settings from the canvas for grid snapping
    let snapSettings: SnapSettings

    /// Device size for coordinate mapping
    let deviceSize: CGSize

    // Drag state
    @State private var dragTarget: DragTarget? = nil
    @State private var dragStartPosition: CGPoint = .zero
    @State private var dragStartHandle: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var newPointID: UUID? = nil

    /// Captured bounding rect midpoint at drag start — used to keep the
    /// element from visually translating while points are moved.
    @State private var dragStartBoundsMid: CGPoint? = nil

    // Box selection state (for marquee-selecting multiple points)
    @State private var isBoxSelecting: Bool = false
    @State private var boxSelectStart: CGPoint? = nil
    @State private var boxSelectEnd: CGPoint? = nil

    private let pointSize: CGFloat = 10
    private let handleSize: CGFloat = 8
    private let hitRadius: CGFloat = 14

    private enum DragTarget: Equatable {
        case point(UUID)
        case handleIn(UUID)
        case handleOut(UUID)
        case newPoint(UUID)
        case boxSelect
    }

    public init(
        elementID: UUID,
        document: DesignDocument,
        selectedPointID: Binding<UUID?>,
        selectedPointIDs: Binding<Set<UUID>>,
        isEditingPath: Binding<Bool>,
        elementOffset: CGPoint,
        snapSettings: SnapSettings,
        deviceSize: CGSize
    ) {
        self.elementID = elementID
        self.document = document
        self._selectedPointID = selectedPointID
        self._selectedPointIDs = selectedPointIDs
        self._isEditingPath = isEditingPath
        self.elementOffset = elementOffset
        self.snapSettings = snapSettings
        self.deviceSize = deviceSize
    }

    // MARK: - Data Access

    private var vectorPath: VectorPath? {
        guard let element = findElement() else { return nil }
        if case .vectorPath(let path, _, _) = element.payload {
            return path
        }
        return nil
    }

    /// The path's bounding rect midpoint — VectorPathView centers itself on this
    /// in the parent ZStack, so we use it to compute the origin for overlay rendering.
    private var pathBoundsMid: CGPoint {
        guard let path = vectorPath else { return CGPoint(x: 50, y: 50) }
        let b = path.boundingRect
        guard b.width > 0 || b.height > 0 else { return CGPoint(x: 50, y: 50) }
        return CGPoint(x: b.midX, y: b.midY)
    }

    private func findElement() -> ElementNode? {
        guard let pageID = document.selectedPageID,
              let page = document.pages.first(where: { $0.id == pageID }) else { return nil }
        return page.rootElement.find(by: elementID)
    }

    // MARK: - Body

    public var body: some View {
        // Fill the entire phone frame. We offset the Canvas content by the
        // element's position so points line up with the rendered element.
        GeometryReader { geo in
            Canvas { context, size in
                guard let path = vectorPath else { return }
                let origin = computeOrigin(in: size)

                drawPathOutline(context: context, path: path, origin: origin)
                drawHandles(context: context, path: path, origin: origin)
                drawPoints(context: context, path: path, origin: origin)

                // Draw path bounding rect (dashed)
                let b = path.boundingRect
                let boundsRect = CGRect(
                    x: origin.x + b.minX,
                    y: origin.y + b.minY,
                    width: b.width,
                    height: b.height
                )
                context.stroke(
                    Path(boundsRect),
                    with: .color(.blue.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )

                // Draw box selection rect
                if isBoxSelecting, let start = boxSelectStart, let end = boxSelectEnd {
                    let selRect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    context.fill(Path(selRect), with: .color(.blue.opacity(0.1)))
                    context.stroke(Path(selRect), with: .color(.blue.opacity(0.6)), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let origin = computeOrigin(in: geo.size)

                        // Convert screen coords to element-local coords
                        let localStart = CGPoint(
                            x: value.startLocation.x - origin.x,
                            y: value.startLocation.y - origin.y
                        )
                        let localCurrent = CGPoint(
                            x: value.location.x - origin.x,
                            y: value.location.y - origin.y
                        )

                        if !isDragging {
                            beginDrag(at: localStart, screenStart: value.startLocation)
                            isDragging = true
                        }

                        if isBoxSelecting {
                            boxSelectEnd = value.location
                            // Live update point selection
                            if let start = boxSelectStart {
                                let rect = normalizedRect(from: start, to: value.location)
                                liveBoxSelectPoints(in: rect, origin: origin)
                            }
                        } else {
                            continueDrag(to: localCurrent, translation: value.translation)
                        }
                    }
                    .onEnded { value in
                        let origin = computeOrigin(in: geo.size)

                        if isBoxSelecting {
                            // Finalize box selection
                            if let start = boxSelectStart {
                                let rect = normalizedRect(from: start, to: value.location)
                                liveBoxSelectPoints(in: rect, origin: origin)
                            }
                            isBoxSelecting = false
                            boxSelectStart = nil
                            boxSelectEnd = nil
                            endDrag()
                            return
                        }

                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist < 3 && dragTarget == nil {
                            let localPos = CGPoint(
                                x: value.startLocation.x - origin.x,
                                y: value.startLocation.y - origin.y
                            )
                            handleTap(at: localPos)
                        }
                        endDrag()
                    }
            )
        }
    }

    /// Compute the origin offset for mapping path coordinates to screen coordinates.
    private func computeOrigin(in size: CGSize) -> CGPoint {
        let mid = pathBoundsMid
        let originX = size.width / 2 + elementOffset.x - mid.x
        let originY = size.height / 2 + elementOffset.y - mid.y
        return CGPoint(x: originX, y: originY)
    }

    /// Normalized rect from two points.
    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x), y: min(a.y, b.y),
            width: abs(b.x - a.x), height: abs(b.y - a.y)
        )
    }

    /// Select all path points whose screen position falls within the given rect.
    private func liveBoxSelectPoints(in screenRect: CGRect, origin: CGPoint) {
        guard let path = vectorPath else { return }
        var newSelection: Set<UUID> = []
        for point in path.points {
            let screenPos = CGPoint(x: origin.x + point.position.x, y: origin.y + point.position.y)
            if screenRect.contains(screenPos) {
                newSelection.insert(point.id)
            }
        }
        if NSEvent.modifierFlags.contains(.shift) {
            selectedPointIDs.formUnion(newSelection)
        } else {
            selectedPointIDs = newSelection
        }
        selectedPointID = selectedPointIDs.first
    }

    // MARK: - Drawing

    private func drawPathOutline(context: GraphicsContext, path vectorPath: VectorPath, origin: CGPoint) {
        let swiftPath = buildSwiftUIPath(from: vectorPath, origin: origin)
        context.stroke(swiftPath, with: .color(.blue.opacity(0.3)), lineWidth: 1.5)
    }

    private func drawPoints(context: GraphicsContext, path: VectorPath, origin: CGPoint) {
        for point in path.points {
            let isSelected = point.id == selectedPointID || selectedPointIDs.contains(point.id)
            let screenPos = CGPoint(x: origin.x + point.position.x, y: origin.y + point.position.y)
            let s = pointSize

            let rect = CGRect(x: screenPos.x - s/2, y: screenPos.y - s/2, width: s, height: s)

            if point.isCurve {
                let circle = Path(ellipseIn: rect)
                context.fill(circle, with: .color(isSelected ? .blue : .white))
                context.stroke(circle, with: .color(.blue), lineWidth: 1.5)
            } else {
                let square = Path(rect)
                context.fill(square, with: .color(isSelected ? .blue : .white))
                context.stroke(square, with: .color(.blue), lineWidth: 1.5)
            }
        }
    }

    private func drawHandles(context: GraphicsContext, path: VectorPath, origin: CGPoint) {
        for point in path.points {
            guard point.id == selectedPointID || selectedPointIDs.contains(point.id) else { continue }
            let screenPos = CGPoint(x: origin.x + point.position.x, y: origin.y + point.position.y)

            if let absIn = point.handleInAbsolute {
                let screenIn = CGPoint(x: origin.x + absIn.x, y: origin.y + absIn.y)
                var line = Path()
                line.move(to: screenPos)
                line.addLine(to: screenIn)
                context.stroke(line, with: .color(.blue.opacity(0.5)), lineWidth: 1)

                let r = CGRect(x: screenIn.x - handleSize/2, y: screenIn.y - handleSize/2, width: handleSize, height: handleSize)
                let dot = Path(ellipseIn: r)
                context.fill(dot, with: .color(.orange))
                context.stroke(dot, with: .color(.white), lineWidth: 1)
            }

            if let absOut = point.handleOutAbsolute {
                let screenOut = CGPoint(x: origin.x + absOut.x, y: origin.y + absOut.y)
                var line = Path()
                line.move(to: screenPos)
                line.addLine(to: screenOut)
                context.stroke(line, with: .color(.blue.opacity(0.5)), lineWidth: 1)

                let r = CGRect(x: screenOut.x - handleSize/2, y: screenOut.y - handleSize/2, width: handleSize, height: handleSize)
                let dot = Path(ellipseIn: r)
                context.fill(dot, with: .color(.orange))
                context.stroke(dot, with: .color(.white), lineWidth: 1)
            }
        }
    }

    // MARK: - Hit Testing (in element-local coordinates)

    private func hitTest(at localPoint: CGPoint) -> DragTarget? {
        guard let path = vectorPath else { return nil }

        // Check handles of selected point first (highest priority)
        if let selectedID = selectedPointID,
           let selectedPoint = path.points.first(where: { $0.id == selectedID }) {
            if let absOut = selectedPoint.handleOutAbsolute {
                if distance(localPoint, absOut) < hitRadius {
                    return .handleOut(selectedID)
                }
            }
            if let absIn = selectedPoint.handleInAbsolute {
                if distance(localPoint, absIn) < hitRadius {
                    return .handleIn(selectedID)
                }
            }
        }

        // Check anchor points (reversed for z-order)
        for point in path.points.reversed() {
            if distance(localPoint, point.position) < hitRadius {
                return .point(point.id)
            }
        }

        return nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Drag Logic

    private func beginDrag(at localPoint: CGPoint, screenStart: CGPoint) {
        guard let target = hitTest(at: localPoint) else {
            // No hit target — start box selection for marquee selecting points
            dragTarget = .boxSelect
            isBoxSelecting = true
            boxSelectStart = screenStart
            boxSelectEnd = screenStart
            return
        }

        dragTarget = target
        guard let path = vectorPath else { return }

        // Capture bounding rect midpoint at drag start for offset compensation
        let b = path.boundingRect
        dragStartBoundsMid = CGPoint(x: b.midX, y: b.midY)

        switch target {
        case .point(let id):
            // If shift is held, add to selection; otherwise single-select
            if NSEvent.modifierFlags.contains(.shift) {
                selectedPointIDs.insert(id)
                selectedPointID = id
            } else if !selectedPointIDs.contains(id) {
                selectedPointID = id
                selectedPointIDs = [id]
            } else {
                selectedPointID = id
            }
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
        case .newPoint, .boxSelect:
            break
        }
    }

    private func continueDrag(to localPoint: CGPoint, translation: CGSize) {
        guard let target = dragTarget else {
            // No target — create new bezier point if dragging far enough
            let dist = hypot(translation.width, translation.height)
            if dist > 5 && newPointID == nil {
                let startLocal = CGPoint(
                    x: localPoint.x - translation.width,
                    y: localPoint.y - translation.height
                )
                startNewBezierPoint(at: startLocal)
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
            var newPos = CGPoint(
                x: dragStartPosition.x + translation.width,
                y: dragStartPosition.y + translation.height
            )
            // Apply snapping to vector point positions
            if snapSettings.isEnabled {
                newPos = snapSettings.snap(newPos)
            }

            // Capture the element's current offset BEFORE the update
            var currentOffsetX: CGFloat = 0
            var currentOffsetY: CGFloat = 0
            if let element = findElement() {
                for mod in element.modifiers {
                    if case .offset(let x, let y) = mod { currentOffsetX = x; currentOffsetY = y }
                }
            }

            // Get the old bounding rect mid before update
            let oldMid = vectorPath.map { CGPoint(x: $0.boundingRect.midX, y: $0.boundingRect.midY) }

            document.updateElement(elementID) { node in
                if case .vectorPath(var path, let stroke, let fill) = node.payload {
                    if let idx = path.points.firstIndex(where: { $0.id == id }) {
                        path.points[idx].position = newPos
                    }
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)

                    // Compensate element offset for bounding rect shift
                    let newBounds = path.boundingRect
                    let newMid = CGPoint(x: newBounds.midX, y: newBounds.midY)
                    if let oldMid = oldMid {
                        let dx = newMid.x - oldMid.x
                        let dy = newMid.y - oldMid.y
                        if abs(dx) > 0.01 || abs(dy) > 0.01 {
                            node.modifiers.removeAll { if case .offset = $0 { return true }; return false }
                            node.modifiers.append(.offset(x: currentOffsetX + dx, y: currentOffsetY + dy))
                        }
                    }
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

        case .boxSelect:
            break // Handled in body gesture
        }
    }

    private func endDrag() {
        dragTarget = nil
        isDragging = false
        newPointID = nil
        dragStartBoundsMid = nil
        isBoxSelecting = false
        boxSelectStart = nil
        boxSelectEnd = nil
    }

    // MARK: - Tap

    private func handleTap(at localPoint: CGPoint) {
        if let target = hitTest(at: localPoint) {
            if case .point(let id) = target {
                if NSEvent.modifierFlags.contains(.shift) {
                    // Shift+click: toggle point in multi-selection
                    if selectedPointIDs.contains(id) {
                        selectedPointIDs.remove(id)
                        if selectedPointID == id {
                            selectedPointID = selectedPointIDs.first
                        }
                    } else {
                        selectedPointIDs.insert(id)
                        selectedPointID = id
                    }
                } else {
                    selectedPointID = id
                    selectedPointIDs = [id]
                }
                return
            }
        }

        guard let path = vectorPath else { return }

        if !path.isClosed || path.points.isEmpty {
            let newPoint = PathPoint(position: localPoint)
            document.updateElement(elementID) { node in
                if case .vectorPath(var p, let stroke, let fill) = node.payload {
                    p.points.append(newPoint)
                    node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
                }
            }
            selectedPointID = newPoint.id
        } else {
            insertPointOnNearestSegment(at: localPoint)
        }
    }

    // MARK: - New Bezier Point

    private func startNewBezierPoint(at localPoint: CGPoint) {
        guard let path = vectorPath else { return }
        guard !path.isClosed || path.points.isEmpty else { return }

        let id = UUID()
        newPointID = id
        let newPoint = PathPoint(id: id, position: localPoint, handleIn: .zero, handleOut: .zero)
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
                    path.points[idx].handleOut = CGPoint(x: translation.width, y: translation.height)
                    path.points[idx].handleIn = CGPoint(x: -translation.width, y: -translation.height)
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

    // MARK: - Path Building

    private func buildSwiftUIPath(from vectorPath: VectorPath, origin: CGPoint) -> Path {
        Path { p in
            guard !vectorPath.points.isEmpty else { return }
            p.move(to: CGPoint(
                x: origin.x + vectorPath.points[0].position.x,
                y: origin.y + vectorPath.points[0].position.y
            ))

            for i in 1..<vectorPath.points.count {
                let prev = vectorPath.points[i - 1]
                let curr = vectorPath.points[i]
                addSegment(to: &p, from: prev, to: curr, origin: origin)
            }

            if vectorPath.isClosed && vectorPath.points.count > 1 {
                addSegment(to: &p, from: vectorPath.points.last!, to: vectorPath.points[0], origin: origin)
                p.closeSubpath()
            }
        }
    }

    private func addSegment(to p: inout Path, from prev: PathPoint, to curr: PathPoint, origin: CGPoint) {
        let currPos = CGPoint(x: origin.x + curr.position.x, y: origin.y + curr.position.y)
        let hasOut = prev.handleOut != nil
        let hasIn = curr.handleIn != nil

        if hasOut && hasIn {
            let c1 = CGPoint(x: origin.x + prev.handleOutAbsolute!.x, y: origin.y + prev.handleOutAbsolute!.y)
            let c2 = CGPoint(x: origin.x + curr.handleInAbsolute!.x, y: origin.y + curr.handleInAbsolute!.y)
            p.addCurve(to: currPos, control1: c1, control2: c2)
        } else if hasOut {
            let c = CGPoint(x: origin.x + prev.handleOutAbsolute!.x, y: origin.y + prev.handleOutAbsolute!.y)
            p.addQuadCurve(to: currPos, control: c)
        } else if hasIn {
            let c = CGPoint(x: origin.x + curr.handleInAbsolute!.x, y: origin.y + curr.handleInAbsolute!.y)
            p.addQuadCurve(to: currPos, control: c)
        } else {
            p.addLine(to: currPos)
        }
    }
}
