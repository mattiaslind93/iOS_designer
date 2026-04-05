import SwiftUI

/// Visual selection indicator shown around the currently selected element.
/// Displays a blue border with resize handles at corners and midpoints.
public struct SelectionOverlay: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Selection border
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)

                // Corner handles
                ResizeHandle().position(x: 0, y: 0)
                ResizeHandle().position(x: w, y: 0)
                ResizeHandle().position(x: 0, y: h)
                ResizeHandle().position(x: w, y: h)

                // Midpoint handles
                ResizeHandle(small: true).position(x: w / 2, y: 0)
                ResizeHandle(small: true).position(x: w / 2, y: h)
                ResizeHandle(small: true).position(x: 0, y: h / 2)
                ResizeHandle(small: true).position(x: w, y: h / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

struct ResizeHandle: View {
    var small: Bool = false

    var body: some View {
        let size: CGFloat = small ? 6 : 8
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
    }
}
