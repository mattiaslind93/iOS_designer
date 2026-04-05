import SwiftUI
import DesignModel

/// The main design canvas with zoom, pan, and the iPhone device frame.
/// Supports element selection and serves as the primary drop target.
public struct CanvasView: View {
    @ObservedObject var document: DesignDocument
    @State private var scale: CGFloat = 0.6
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showGrid: Bool = false

    public init(document: DesignDocument) {
        self.document = document
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background (infinite area)
                canvasBackground

                // Phone frame centered
                if let page = document.selectedPage {
                    phoneFrame(for: page)
                        .scaleEffect(scale)
                        .offset(offset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .onTapGesture {
                // Deselect when tapping canvas background
                document.selectedElementID = nil
            }
            .overlay(alignment: .bottomTrailing) {
                canvasControls
            }
        }
    }

    // MARK: - Canvas Background

    private var canvasBackground: some View {
        // Subtle dot pattern background
        Canvas { context, size in
            let dotSpacing: CGFloat = 20 * scale
            let dotSize: CGFloat = 1.5
            let color = Color.gray.opacity(0.2)

            let offsetX = offset.width.truncatingRemainder(dividingBy: dotSpacing)
            let offsetY = offset.height.truncatingRemainder(dividingBy: dotSpacing)

            var x = offsetX
            while x < size.width {
                var y = offsetY
                while y < size.height {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    y += dotSpacing
                }
                x += dotSpacing
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Phone Frame

    private func phoneFrame(for page: DesignPage) -> some View {
        PhoneFrameView(
            deviceFrame: page.deviceFrame,
            isDarkMode: page.isDarkMode,
            showSafeAreas: showGrid
        ) {
            ZStack {
                // Grid overlay
                if showGrid {
                    GridOverlay(deviceSize: page.deviceFrame.size)
                }

                // Element tree
                ElementRenderer(
                    node: page.rootElement,
                    selectedID: document.selectedElementID
                ) { id in
                    document.selectedElementID = id
                }
            }
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = max(0.1, min(3.0, scale * value.magnification))
                scale = newScale
            }
    }

    // MARK: - Controls

    private var canvasControls: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.smooth) { scale = min(3.0, scale * 1.25) }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }

            Text("\(Int(scale * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.smooth) { scale = max(0.1, scale / 1.25) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }

            Divider().frame(width: 20)

            Button {
                withAnimation(.smooth) {
                    scale = 0.6
                    offset = .zero
                    lastOffset = .zero
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }

            Button {
                showGrid.toggle()
            } label: {
                Image(systemName: showGrid ? "grid.circle.fill" : "grid.circle")
            }
        }
        .buttonStyle(.borderless)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
