import SwiftUI
import DesignModel

/// Overlay that shows when editing a vector path in edit mode.
/// Displays anchor points, bezier handles, and allows:
/// - Clicking to select a point
/// - Dragging points to move them
/// - Dragging handles to adjust bezier curves
/// - Clicking on empty area to add new points (for open/free paths)
/// - Option+click on a segment to insert a new point
/// - Delete key to remove selected point
public struct PathEditingOverlay: View {
    let elementID: UUID
    @ObservedObject var document: DesignDocument
    @Binding var selectedPointID: UUID?
    @Binding var isEditingPath: Bool

    /// Size of the element's frame (from modifiers)
    let frameSize: CGSize

    // Drag state
    @State private var draggedPointID: UUID? = nil
    @State private var draggedHandleType: HandleType? = nil
    @State private var dragOffset: CGSize = .zero

    // New point creation via drag (click + drag to set bezier handles)
    @State private var isCreatingNewPoint: Bool = false
    @State private var newPointID: UUID? = nil
    @State private var newPointDragOffset: CGSize = .zero

    private enum HandleType {
        case handleIn, handleOut
    }

    // Visual constants
    private let pointSize: CGFloat = 10
    private let handleSize: CGFloat = 8
    private let handleLineWidth: CGFloat = 1
    private let hitAreaSize: CGFloat = 20

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

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Translucent background to capture clicks and drags
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dist = hypot(value.translation.width, value.translation.height)
                                if dist > 3 && !isCreatingNewPoint {
                                    // Start creating a new point with bezier handles
                                    startNewBezierPoint(at: value.startLocation)
                                }
                                if isCreatingNewPoint {
                                    newPointDragOffset = value.translation
                                    // Live-update handles as user drags
                                    updateNewPointHandles(translation: value.translation)
                                }
                            }
                            .onEnded { value in
                                let dist = hypot(value.translation.width, value.translation.height)
                                if dist <= 3 {
                                    // Tap: add corner point
                                    handleBackgroundTap(at: value.startLocation, in: geo.size)
                                } else if isCreatingNewPoint {
                                    // Drag ended: handles already set
                                    isCreatingNewPoint = false
                                    newPointDragOffset = .zero
                                }
                            }
                    )

                if let path = vectorPath {
                    // Draw path outline (thin, for context)
                    pathOutline(path)
                        .allowsHitTesting(false)

                    // Draw bezier handle lines and handles for selected point
                    ForEach(path.points) { point in
                        if point.id == selectedPointID {
                            handleLines(for: point)
                            handleDots(for: point)
                        }
                    }

                    // Draw anchor points (on top)
                    ForEach(path.points) { point in
                        anchorPoint(for: point, in: path)
                    }
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }

    // MARK: - Path Outline

    private func pathOutline(_ path: VectorPath) -> some View {
        VectorPathView(
            path: path,
            stroke: VectorStrokeStyle(color: .custom(red: 0.2, green: 0.5, blue: 1.0, opacity: 0.3), width: 1.5),
            fill: nil
        )
    }

    // MARK: - Anchor Points

    private func anchorPoint(for point: PathPoint, in path: VectorPath) -> some View {
        let isSelected = point.id == selectedPointID
        let isCurve = point.isCurve
        let pos = effectivePosition(for: point)

        return Group {
            if isCurve {
                // Curve point: circle
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.white)
                    .frame(width: pointSize, height: pointSize)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            } else {
                // Corner point: square
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.white)
                    .frame(width: pointSize, height: pointSize)
                    .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .position(pos)
        .gesture(pointDragGesture(for: point))
        .onTapGesture {
            selectedPointID = point.id
        }
        // Larger hit area
        .contentShape(Rectangle().size(width: hitAreaSize, height: hitAreaSize).offset(x: -hitAreaSize/2, y: -hitAreaSize/2))
    }

    // MARK: - Bezier Handle Lines

    private func handleLines(for point: PathPoint) -> some View {
        let pos = effectivePosition(for: point)

        return ZStack {
            // Handle In line
            if point.handleIn != nil {
                let absIn = effectiveHandleIn(for: point)
                Path { p in
                    p.move(to: pos)
                    p.addLine(to: absIn)
                }
                .stroke(Color.accentColor.opacity(0.5), lineWidth: handleLineWidth)
            }

            // Handle Out line
            if point.handleOut != nil {
                let absOut = effectiveHandleOut(for: point)
                Path { p in
                    p.move(to: pos)
                    p.addLine(to: absOut)
                }
                .stroke(Color.accentColor.opacity(0.5), lineWidth: handleLineWidth)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bezier Handle Dots

    private func handleDots(for point: PathPoint) -> some View {
        ZStack {
            // Handle In
            if point.handleIn != nil {
                let absIn = effectiveHandleIn(for: point)
                Circle()
                    .fill(Color.orange)
                    .frame(width: handleSize, height: handleSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .position(absIn)
                    .gesture(handleDragGesture(for: point, type: .handleIn))
            }

            // Handle Out
            if point.handleOut != nil {
                let absOut = effectiveHandleOut(for: point)
                Circle()
                    .fill(Color.orange)
                    .frame(width: handleSize, height: handleSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .position(absOut)
                    .gesture(handleDragGesture(for: point, type: .handleOut))
            }
        }
    }

    // MARK: - Effective Positions (with drag offset)

    private func effectivePosition(for point: PathPoint) -> CGPoint {
        if draggedPointID == point.id && draggedHandleType == nil {
            return CGPoint(
                x: point.position.x + dragOffset.width,
                y: point.position.y + dragOffset.height
            )
        }
        return point.position
    }

    private func effectiveHandleIn(for point: PathPoint) -> CGPoint {
        guard let h = point.handleIn else { return point.position }
        let pos = effectivePosition(for: point)
        if draggedPointID == point.id && draggedHandleType == .handleIn {
            return CGPoint(
                x: pos.x + h.x + dragOffset.width,
                y: pos.y + h.y + dragOffset.height
            )
        }
        return CGPoint(x: pos.x + h.x, y: pos.y + h.y)
    }

    private func effectiveHandleOut(for point: PathPoint) -> CGPoint {
        guard let h = point.handleOut else { return point.position }
        let pos = effectivePosition(for: point)
        if draggedPointID == point.id && draggedHandleType == .handleOut {
            return CGPoint(
                x: pos.x + h.x + dragOffset.width,
                y: pos.y + h.y + dragOffset.height
            )
        }
        return CGPoint(x: pos.x + h.x, y: pos.y + h.y)
    }

    // MARK: - Point Drag Gesture

    private func pointDragGesture(for point: PathPoint) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                draggedPointID = point.id
                draggedHandleType = nil
                dragOffset = value.translation
                selectedPointID = point.id
            }
            .onEnded { value in
                // Commit position change
                let dx = value.translation.width
                let dy = value.translation.height
                document.updateElement(elementID) { node in
                    if case .vectorPath(var path, let stroke, let fill) = node.payload {
                        if let idx = path.points.firstIndex(where: { $0.id == point.id }) {
                            path.points[idx].position.x += dx
                            path.points[idx].position.y += dy
                        }
                        node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                    }
                }
                draggedPointID = nil
                dragOffset = .zero
            }
    }

    // MARK: - Handle Drag Gesture

    private func handleDragGesture(for point: PathPoint, type: HandleType) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                draggedPointID = point.id
                draggedHandleType = type
                dragOffset = value.translation
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                document.updateElement(elementID) { node in
                    if case .vectorPath(var path, let stroke, let fill) = node.payload {
                        if let idx = path.points.firstIndex(where: { $0.id == point.id }) {
                            switch type {
                            case .handleIn:
                                if var h = path.points[idx].handleIn {
                                    h.x += dx
                                    h.y += dy
                                    path.points[idx].handleIn = h
                                    // Mirror to handleOut for smooth curves (unless Option held)
                                    if !NSEvent.modifierFlags.contains(.option) {
                                        path.points[idx].handleOut = CGPoint(x: -h.x, y: -h.y)
                                    }
                                }
                            case .handleOut:
                                if var h = path.points[idx].handleOut {
                                    h.x += dx
                                    h.y += dy
                                    path.points[idx].handleOut = h
                                    // Mirror to handleIn for smooth curves (unless Option held)
                                    if !NSEvent.modifierFlags.contains(.option) {
                                        path.points[idx].handleIn = CGPoint(x: -h.x, y: -h.y)
                                    }
                                }
                            }
                        }
                        node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                    }
                }
                draggedPointID = nil
                draggedHandleType = nil
                dragOffset = .zero
            }
    }

    // MARK: - New Point with Bezier Handles (click + drag)

    private func startNewBezierPoint(at location: CGPoint) {
        guard let path = vectorPath else { return }
        guard !path.isClosed || path.points.isEmpty else {
            // For closed paths, insert on segment instead
            insertPointOnNearestSegment(at: location)
            return
        }

        isCreatingNewPoint = true
        let id = UUID()
        newPointID = id
        let newPoint = PathPoint(
            id: id,
            position: location,
            handleIn: CGPoint.zero,
            handleOut: CGPoint.zero
        )
        document.updateElement(elementID) { node in
            if case .vectorPath(var p, let stroke, let fill) = node.payload {
                p.points.append(newPoint)
                node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
            }
        }
        selectedPointID = id
    }

    private func updateNewPointHandles(translation: CGSize) {
        guard let pointID = newPointID else { return }
        document.updateElement(elementID) { node in
            if case .vectorPath(var path, let stroke, let fill) = node.payload {
                if let idx = path.points.firstIndex(where: { $0.id == pointID }) {
                    // HandleOut follows drag direction, handleIn mirrors it
                    let handleOut = CGPoint(x: translation.width, y: translation.height)
                    let handleIn = CGPoint(x: -translation.width, y: -translation.height)
                    path.points[idx].handleOut = handleOut
                    path.points[idx].handleIn = handleIn
                    node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                }
            }
        }
    }

    // MARK: - Background Tap (add corner point)

    private func handleBackgroundTap(at location: CGPoint, in size: CGSize) {
        guard let path = vectorPath else { return }

        // If path is open or empty, add a new corner point at click location
        if !path.isClosed || path.points.isEmpty {
            let newPoint = PathPoint(position: location)
            document.updateElement(elementID) { node in
                if case .vectorPath(var p, let stroke, let fill) = node.payload {
                    p.points.append(newPoint)
                    node.payload = .vectorPath(path: p, stroke: stroke, fill: fill)
                }
            }
            selectedPointID = newPoint.id
        } else {
            // For closed paths, insert point on nearest segment
            insertPointOnNearestSegment(at: location)
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

            // Simple line distance for now
            let (dist, t) = distanceToSegment(point: point, from: p0.position, to: p1.position)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i + 1
                bestT = t
            }
        }

        // Only insert if close enough (within 30pt)
        guard bestDist < 30 else {
            selectedPointID = nil
            return
        }

        let p0 = path.points[bestIndex - 1]
        let p1 = path.points[bestIndex % path.points.count]

        // Interpolate position
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
            let d = hypot(point.x - from.x, point.y - from.y)
            return (d, 0)
        }
        var t = ((point.x - from.x) * dx + (point.y - from.y) * dy) / lenSq
        t = max(0, min(1, t))
        let proj = CGPoint(x: from.x + t * dx, y: from.y + t * dy)
        let dist = hypot(point.x - proj.x, point.y - proj.y)
        return (dist, t)
    }
}

// MARK: - Path Editing Key Commands

/// Handles keyboard events during path editing: Delete to remove point,
/// Escape to deselect, Tab to exit edit mode.
public struct PathEditingKeyHandler: ViewModifier {
    let elementID: UUID
    @ObservedObject var document: DesignDocument
    @Binding var selectedPointID: UUID?
    @Binding var isEditingPath: Bool

    public func body(content: Content) -> some View {
        content
            .onKeyPress(.delete) {
                deleteSelectedPoint()
                return .handled
            }
            .onKeyPress(.init(Character(UnicodeScalar(127)))) { // Backspace
                deleteSelectedPoint()
                return .handled
            }
            .onKeyPress(.escape) {
                if selectedPointID != nil {
                    selectedPointID = nil
                } else {
                    isEditingPath = false
                }
                return .handled
            }
            .onKeyPress(.tab) {
                isEditingPath = false
                return .handled
            }
    }

    private func deleteSelectedPoint() {
        guard let pointID = selectedPointID else { return }
        document.updateElement(elementID) { node in
            if case .vectorPath(var path, let stroke, let fill) = node.payload {
                path.points.removeAll { $0.id == pointID }
                node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
            }
        }
        selectedPointID = nil
    }
}

extension View {
    public func pathEditingKeyHandler(
        elementID: UUID,
        document: DesignDocument,
        selectedPointID: Binding<UUID?>,
        isEditingPath: Binding<Bool>
    ) -> some View {
        modifier(PathEditingKeyHandler(
            elementID: elementID,
            document: document,
            selectedPointID: selectedPointID,
            isEditingPath: isEditingPath
        ))
    }
}
