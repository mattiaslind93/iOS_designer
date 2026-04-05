import SwiftUI
import DesignModel

/// Grid overlay with support for different snap modes and iOS layout guides.
public struct GridOverlay: View {
    let deviceSize: CGSize
    let gridSize: CGFloat
    let showGrid: Bool
    let snapMode: SnapMode?
    let safeAreaInsets: SafeAreaInsets?

    public init(
        deviceSize: CGSize,
        gridSize: CGFloat = 8,
        showGrid: Bool = true,
        snapMode: SnapMode? = nil,
        safeAreaInsets: SafeAreaInsets? = nil
    ) {
        self.deviceSize = deviceSize
        self.gridSize = gridSize
        self.showGrid = showGrid
        self.snapMode = snapMode
        self.safeAreaInsets = safeAreaInsets
    }

    public var body: some View {
        if showGrid {
            ZStack {
                // Base grid
                Canvas { context, size in
                    let color = Color.gray.opacity(0.12)

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

                    // Center lines
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let centerColor = Color.blue.opacity(0.2)

                    let vCenter = Path { p in
                        p.move(to: CGPoint(x: centerX, y: 0))
                        p.addLine(to: CGPoint(x: centerX, y: size.height))
                    }
                    context.stroke(vCenter, with: .color(centerColor), lineWidth: 1)

                    let hCenter = Path { p in
                        p.move(to: CGPoint(x: 0, y: centerY))
                        p.addLine(to: CGPoint(x: size.width, y: centerY))
                    }
                    context.stroke(hCenter, with: .color(centerColor), lineWidth: 1)
                }

                // iOS Layout guides
                if snapMode == .iosLayout, let insets = safeAreaInsets {
                    iOSLayoutGuides(insets: insets)
                }
            }
            .frame(width: deviceSize.width, height: deviceSize.height)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func iOSLayoutGuides(insets: SafeAreaInsets) -> some View {
        let guideColor = Color.pink.opacity(0.25)
        let marginColor = Color.orange.opacity(0.2)
        let margin: CGFloat = 16

        Canvas { context, size in
            // Standard margins (16pt from edges)
            let leftMargin = Path { p in
                p.move(to: CGPoint(x: margin, y: 0))
                p.addLine(to: CGPoint(x: margin, y: size.height))
            }
            context.stroke(leftMargin, with: .color(marginColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            let rightMargin = Path { p in
                p.move(to: CGPoint(x: size.width - margin, y: 0))
                p.addLine(to: CGPoint(x: size.width - margin, y: size.height))
            }
            context.stroke(rightMargin, with: .color(marginColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Safe area content top
            let safeTop = Path { p in
                p.move(to: CGPoint(x: 0, y: insets.top))
                p.addLine(to: CGPoint(x: size.width, y: insets.top))
            }
            context.stroke(safeTop, with: .color(guideColor), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))

            // Safe area content bottom
            let safeBottom = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - insets.bottom))
                p.addLine(to: CGPoint(x: size.width, y: size.height - insets.bottom))
            }
            context.stroke(safeBottom, with: .color(guideColor), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))

            // Tab bar position (49pt from bottom safe area)
            let tabBarTop = size.height - insets.bottom - 49
            let tabLine = Path { p in
                p.move(to: CGPoint(x: 0, y: tabBarTop))
                p.addLine(to: CGPoint(x: size.width, y: tabBarTop))
            }
            context.stroke(tabLine, with: .color(Color.teal.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

            // Navigation bar large title area (approx 96pt from safe top)
            let navBottom = insets.top + 96
            let navLine = Path { p in
                p.move(to: CGPoint(x: 0, y: navBottom))
                p.addLine(to: CGPoint(x: size.width, y: navBottom))
            }
            context.stroke(navLine, with: .color(Color.teal.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }
    }
}
