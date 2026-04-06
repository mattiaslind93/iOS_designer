import SwiftUI
import DesignModel

/// Renders a target vector element with boolean operations applied from sibling vector elements.
///
/// Dynamically sizes to the combined bounding box of all involved paths.
/// Uses Canvas rendering with blend modes for correct boolean compositing:
/// - **Subtract**: Erases cutter area from target (destinationOut)
/// - **Union**: Renders both shapes combined
/// - **Intersect**: Only shows where both shapes overlap (destinationIn)
/// - **Difference (XOR)**: Shows non-overlapping areas (even-odd fill)
struct BooleanMaskedElement: View {
    let target: ElementNode
    let booleans: [ElementNode]
    let selectedID: UUID?
    let snapSettings: SnapSettings
    @Binding var isEditingPath: Bool
    @Binding var selectedPointID: UUID?
    var document: DesignDocument?
    let onSelect: (UUID) -> Void
    let onMove: (UUID, CGFloat, CGFloat) -> Void

    var body: some View {
        guard case .vectorPath(let targetPath, let targetStroke, let targetFill) = target.payload else {
            return AnyView(EmptyView())
        }

        let fillColor = (targetFill ?? .system(.accentColor)).swiftUIColor
        let strokePad = (targetStroke?.width ?? 2) / 2 + 2

        // Compute the combined bounding rect in a shared coordinate space.
        // We use the parent's coordinate space where each element is centered + offset.
        var combinedBounds = pathBoundsInParent(path: targetPath, node: target)

        // Collect boolean paths with their relative offsets
        var boolOps: [(BooleanOperation, Path)] = []
        for boolNode in booleans {
            guard let config = boolNode.booleanConfig,
                  case .vectorPath(let boolPath, _, _) = boolNode.payload else { continue }

            let boolBounds = pathBoundsInParent(path: boolPath, node: boolNode)
            combinedBounds = combinedBounds.union(boolBounds)

            // Build the boolean path in parent coordinates
            let boolParentPath = buildPathInParent(from: boolPath, node: boolNode)
            boolOps.append((config.operation, boolParentPath))
        }

        // Add stroke padding
        let canvasBounds = combinedBounds.insetBy(dx: -strokePad, dy: -strokePad)
        let canvasSize = CGSize(
            width: max(canvasBounds.width, 1),
            height: max(canvasBounds.height, 1)
        )

        // Build target path in parent coordinates
        let targetParentPath = buildPathInParent(from: targetPath, node: target)

        return AnyView(
            Canvas { context, size in
                // Translate from parent coords to canvas-local coords
                let tx = -canvasBounds.minX
                let ty = -canvasBounds.minY

                // Translate all paths to canvas-local space
                let localTarget = targetParentPath.offsetBy(dx: tx, dy: ty)

                for (operation, boolPath) in boolOps {
                    let localBool = boolPath.offsetBy(dx: tx, dy: ty)

                    switch operation {
                    case .subtract:
                        context.drawLayer { layerCtx in
                            layerCtx.fill(localTarget, with: .color(fillColor))
                            layerCtx.blendMode = .destinationOut
                            layerCtx.fill(localBool, with: .color(.white))
                        }
                        // Stroke both outlines
                        if let stroke = targetStroke {
                            strokePath(&context, localTarget, stroke)
                            // Stroke the cutter outline too (dashed, dimmed)
                            context.stroke(localBool, with: .color(stroke.color.swiftUIColor.opacity(0.3)),
                                style: StrokeStyle(lineWidth: stroke.width * 0.5, dash: [4, 4]))
                        }

                    case .union:
                        context.fill(localTarget, with: .color(fillColor))
                        context.fill(localBool, with: .color(fillColor))
                        if let stroke = targetStroke {
                            // Stroke outer edges only — draw both, then erase inner overlaps
                            context.drawLayer { layerCtx in
                                layerCtx.stroke(localTarget, with: .color(stroke.color.swiftUIColor),
                                    style: StrokeStyle(lineWidth: stroke.width, lineCap: stroke.lineCap.swiftUIValue,
                                        lineJoin: stroke.lineJoin.swiftUIValue))
                                layerCtx.stroke(localBool, with: .color(stroke.color.swiftUIColor),
                                    style: StrokeStyle(lineWidth: stroke.width, lineCap: stroke.lineCap.swiftUIValue,
                                        lineJoin: stroke.lineJoin.swiftUIValue))
                            }
                        }

                    case .intersect:
                        context.drawLayer { layerCtx in
                            layerCtx.fill(localTarget, with: .color(fillColor))
                            layerCtx.blendMode = .destinationIn
                            layerCtx.fill(localBool, with: .color(.white))
                        }
                        if let stroke = targetStroke {
                            strokePath(&context, localTarget, stroke)
                        }

                    case .difference:
                        var combined = localTarget
                        combined.addPath(localBool)
                        context.fill(combined, with: .color(fillColor), style: FillStyle(eoFill: true))
                        if let stroke = targetStroke {
                            strokePath(&context, localTarget, stroke)
                            strokePath(&context, localBool, stroke)
                        }
                    }
                }

                // If no boolean operations matched, render normally
                if boolOps.isEmpty {
                    let localTarget = targetParentPath.offsetBy(dx: tx, dy: ty)
                    context.fill(localTarget, with: .color(fillColor))
                    if let stroke = targetStroke {
                        strokePath(&context, localTarget, stroke)
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            // Position the canvas so its content aligns with the parent layout
            .offset(x: canvasBounds.midX, y: canvasBounds.midY)
            .applyModifiers(target.modifiers.filter { mod in
                if case .offset = mod { return false }
                if case .frame = mod { return false }
                if case .foregroundStyle = mod { return false }
                return true
            })
            .contentShape(Rectangle())
            .overlay {
                if selectedID == target.id {
                    SelectionOverlay()
                }
            }
            .onTapGesture {
                onSelect(target.id)
            }
            .id(target.id)
        )
    }

    // MARK: - Stroke Helper

    private func strokePath(_ context: inout GraphicsContext, _ path: Path, _ stroke: VectorStrokeStyle) {
        context.stroke(
            path,
            with: .color(stroke.color.swiftUIColor),
            style: StrokeStyle(
                lineWidth: stroke.width,
                lineCap: stroke.lineCap.swiftUIValue,
                lineJoin: stroke.lineJoin.swiftUIValue,
                miterLimit: stroke.miterLimit,
                dash: stroke.dashPattern
            )
        )
    }

    // MARK: - Coordinate Space Helpers

    /// Compute the bounding rect of a vector path in the parent's coordinate space.
    /// In a centered ZStack, element origin = -elementSize/2 + elementOffset
    private func pathBoundsInParent(path: VectorPath, node: ElementNode) -> CGRect {
        let size = frameSize(of: node)
        let off = elementOffset(of: node)
        let localBounds = path.boundingRect

        // Element's top-left in parent space (centered layout)
        let originX = -size.width / 2 + off.x
        let originY = -size.height / 2 + off.y

        return CGRect(
            x: originX + localBounds.minX,
            y: originY + localBounds.minY,
            width: localBounds.width,
            height: localBounds.height
        )
    }

    /// Build a SwiftUI Path with points translated to parent coordinate space.
    private func buildPathInParent(from vectorPath: VectorPath, node: ElementNode) -> Path {
        let size = frameSize(of: node)
        let off = elementOffset(of: node)
        let originX = -size.width / 2 + off.x
        let originY = -size.height / 2 + off.y
        return buildPath(from: vectorPath, offset: CGPoint(x: originX, y: originY))
    }

    // MARK: - Element Info

    private func frameSize(of node: ElementNode) -> CGSize {
        var w: CGFloat = 100
        var h: CGFloat = 100
        for mod in node.modifiers {
            if case .frame(let fw, let fh, _, _, _, _, _) = mod {
                if let fw { w = fw }
                if let fh { h = fh }
            }
        }
        return CGSize(width: w, height: h)
    }

    private func elementOffset(of node: ElementNode) -> CGPoint {
        for mod in node.modifiers {
            if case .offset(let x, let y) = mod {
                return CGPoint(x: x, y: y)
            }
        }
        return .zero
    }

    // MARK: - Path Building

    private func buildPath(from vectorPath: VectorPath, offset: CGPoint = .zero) -> Path {
        Path { p in
            guard !vectorPath.points.isEmpty else { return }
            p.move(to: CGPoint(
                x: vectorPath.points[0].position.x + offset.x,
                y: vectorPath.points[0].position.y + offset.y
            ))
            for i in 1..<vectorPath.points.count {
                addSegment(to: &p, from: vectorPath.points[i - 1], to: vectorPath.points[i], offset: offset)
            }
            if vectorPath.isClosed && vectorPath.points.count > 1 {
                addSegment(to: &p, from: vectorPath.points.last!, to: vectorPath.points[0], offset: offset)
                p.closeSubpath()
            }
        }
    }

    private func addSegment(to p: inout Path, from prev: PathPoint, to curr: PathPoint, offset: CGPoint) {
        let currPos = CGPoint(x: curr.position.x + offset.x, y: curr.position.y + offset.y)
        let hasOut = prev.handleOut != nil
        let hasIn = curr.handleIn != nil

        if hasOut && hasIn {
            let c1 = CGPoint(x: prev.handleOutAbsolute!.x + offset.x, y: prev.handleOutAbsolute!.y + offset.y)
            let c2 = CGPoint(x: curr.handleInAbsolute!.x + offset.x, y: curr.handleInAbsolute!.y + offset.y)
            p.addCurve(to: currPos, control1: c1, control2: c2)
        } else if hasOut {
            let c = CGPoint(x: prev.handleOutAbsolute!.x + offset.x, y: prev.handleOutAbsolute!.y + offset.y)
            p.addQuadCurve(to: currPos, control: c)
        } else if hasIn {
            let c = CGPoint(x: curr.handleInAbsolute!.x + offset.x, y: curr.handleInAbsolute!.y + offset.y)
            p.addQuadCurve(to: currPos, control: c)
        } else {
            p.addLine(to: currPos)
        }
    }
}
