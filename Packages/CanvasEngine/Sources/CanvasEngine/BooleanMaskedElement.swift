import SwiftUI
import DesignModel

/// Renders a target vector element with boolean operations applied from sibling vector elements.
///
/// Uses Canvas rendering with blend modes for correct boolean compositing:
/// - **Subtract**: Renders target, then erases where the boolean shape overlaps (destinationOut)
/// - **Union**: Renders both shapes combined into one
/// - **Intersect**: Only shows where both shapes overlap
/// - **Difference (XOR)**: Shows non-overlapping areas of both shapes
///
/// Coordinate mapping: Both the target and boolean elements have path points in their own
/// local coordinate space (typically 0..frameWidth, 0..frameHeight). Since both are children
/// of the same parent (ZStack), they're centered. We compute the boolean path's offset
/// relative to the target's coordinate space using their respective frame sizes and offsets.
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

        let targetSize = frameSize(of: target)
        let targetOff = elementOffset(of: target)

        return AnyView(
            Canvas { context, size in
                let fillColor = (targetFill ?? .system(.accentColor)).swiftUIColor

                // Determine which operations we need
                for boolNode in booleans {
                    guard let config = boolNode.booleanConfig,
                          case .vectorPath(let boolPath, _, _) = boolNode.payload else { continue }

                    let boolSize = frameSize(of: boolNode)
                    let boolOff = elementOffset(of: boolNode)

                    // Offset to convert boolean points from bool-local to target-local coords:
                    // In the parent ZStack (centered), each element's origin is at:
                    //   parentCenter - elementSize/2 + elementOffset
                    // So bool-local → target-local:
                    //   target_local = bool_local + (targetSize/2 - boolSize/2) + (boolOffset - targetOffset)
                    let dx = targetSize.width / 2 - boolSize.width / 2 + boolOff.x - targetOff.x
                    let dy = targetSize.height / 2 - boolSize.height / 2 + boolOff.y - targetOff.y
                    let relativeOffset = CGPoint(x: dx, y: dy)

                    let targetSwiftPath = buildPath(from: targetPath)
                    let boolSwiftPath = buildPath(from: boolPath, offset: relativeOffset)

                    switch config.operation {
                    case .subtract:
                        renderSubtract(
                            context: &context, size: size,
                            targetPath: targetSwiftPath, cutterPath: boolSwiftPath,
                            fillColor: fillColor,
                            stroke: targetStroke
                        )
                    case .union:
                        renderUnion(
                            context: &context, size: size,
                            targetPath: targetSwiftPath, addPath: boolSwiftPath,
                            fillColor: fillColor, addColor: fillColor,
                            stroke: targetStroke
                        )
                    case .intersect:
                        renderIntersect(
                            context: &context, size: size,
                            targetPath: targetSwiftPath, maskPath: boolSwiftPath,
                            fillColor: fillColor,
                            stroke: targetStroke
                        )
                    case .difference:
                        renderDifference(
                            context: &context, size: size,
                            pathA: targetSwiftPath, pathB: boolSwiftPath,
                            fillColor: fillColor,
                            stroke: targetStroke
                        )
                    }
                }

                // If no boolean operations matched, just render the target normally
                if booleans.allSatisfy({ $0.booleanConfig == nil }) {
                    let p = buildPath(from: targetPath)
                    context.fill(p, with: .color(fillColor))
                    if let stroke = targetStroke {
                        strokePath(&context, p, stroke)
                    }
                }
            }
            .frame(width: targetSize.width, height: targetSize.height)
            .applyModifiers(target.modifiers.filter { mod in
                if case .offset = mod { return false }
                if case .frame = mod { return false }  // frame handled above
                if case .foregroundStyle = mod { return false }  // fill handled in canvas
                return true
            })
            .contentShape(Rectangle())
            .overlay {
                if selectedID == target.id {
                    SelectionOverlay()
                }
            }
            .offset(CGSize(width: targetOff.x, height: targetOff.y))
            .onTapGesture {
                onSelect(target.id)
            }
            .id(target.id)
        )
    }

    // MARK: - Boolean Renderers

    /// Subtract: Draw target, then erase where cutter overlaps
    private func renderSubtract(
        context: inout GraphicsContext, size: CGSize,
        targetPath: Path, cutterPath: Path,
        fillColor: Color, stroke: VectorStrokeStyle?
    ) {
        // Draw into a layer so destinationOut only affects the target
        context.drawLayer { layerCtx in
            // 1. Fill the target
            layerCtx.fill(targetPath, with: .color(fillColor))
            // 2. Erase the cutter area
            layerCtx.blendMode = .destinationOut
            layerCtx.fill(cutterPath, with: .color(.white))
        }

        // Stroke the resulting outline
        if let stroke {
            strokePath(&context, targetPath, stroke)
        }
    }

    /// Union: Draw both shapes combined
    private func renderUnion(
        context: inout GraphicsContext, size: CGSize,
        targetPath: Path, addPath: Path,
        fillColor: Color, addColor: Color, stroke: VectorStrokeStyle?
    ) {
        context.fill(targetPath, with: .color(fillColor))
        context.fill(addPath, with: .color(fillColor))

        if let stroke {
            strokePath(&context, targetPath, stroke)
            strokePath(&context, addPath, stroke)
        }
    }

    /// Intersect: Only show where both shapes overlap
    private func renderIntersect(
        context: inout GraphicsContext, size: CGSize,
        targetPath: Path, maskPath: Path,
        fillColor: Color, stroke: VectorStrokeStyle?
    ) {
        context.drawLayer { layerCtx in
            // 1. Fill the target
            layerCtx.fill(targetPath, with: .color(fillColor))
            // 2. Erase everything OUTSIDE the mask (keep only intersection)
            layerCtx.blendMode = .destinationIn
            layerCtx.fill(maskPath, with: .color(.white))
        }

        if let stroke {
            // Stroke only the intersection outline
            strokePath(&context, targetPath, stroke)
        }
    }

    /// Difference (XOR): Show non-overlapping areas of both shapes
    private func renderDifference(
        context: inout GraphicsContext, size: CGSize,
        pathA: Path, pathB: Path,
        fillColor: Color, stroke: VectorStrokeStyle?
    ) {
        // Use even-odd fill rule on combined path for XOR effect
        var combined = pathA
        combined.addPath(pathB)
        context.fill(combined, with: .color(fillColor), style: FillStyle(eoFill: true))

        if let stroke {
            strokePath(&context, pathA, stroke)
            strokePath(&context, pathB, stroke)
        }
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

    // MARK: - Element Info Helpers

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
