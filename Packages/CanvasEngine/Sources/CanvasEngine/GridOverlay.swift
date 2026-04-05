import SwiftUI
import DesignModel

/// 8pt grid overlay with optional fine grid for precise alignment.
public struct GridOverlay: View {
    let deviceSize: CGSize
    let gridSize: CGFloat
    let showGrid: Bool

    public init(deviceSize: CGSize, gridSize: CGFloat = 8, showGrid: Bool = true) {
        self.deviceSize = deviceSize
        self.gridSize = gridSize
        self.showGrid = showGrid
    }

    public var body: some View {
        if showGrid {
            Canvas { context, size in
                let color = Color.gray.opacity(0.15)

                // Vertical lines
                var x: CGFloat = 0
                while x <= size.width {
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                    x += gridSize
                }

                // Horizontal lines
                var y: CGFloat = 0
                while y <= size.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                    y += gridSize
                }
            }
            .frame(width: deviceSize.width, height: deviceSize.height)
            .allowsHitTesting(false)
        }
    }

    /// Snap a value to the nearest grid point
    public static func snap(_ value: CGFloat, to gridSize: CGFloat) -> CGFloat {
        (value / gridSize).rounded() * gridSize
    }
}
