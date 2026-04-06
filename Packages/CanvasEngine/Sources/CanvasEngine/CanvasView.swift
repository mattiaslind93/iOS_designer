import SwiftUI
import DesignModel

/// The main design canvas with zoom, pan (Alt+drag), and the iPhone device frame.
/// Supports element selection, drag-to-move elements, and snapping.
public struct CanvasView: View {
    @ObservedObject var document: DesignDocument
    @State private var scale: CGFloat = 0.6
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showGrid: Bool = false
    @State private var snapSettings: SnapSettings = SnapSettings()

    /// Whether we're in vector path edit mode (editing points/handles)
    @State private var isEditingPath: Bool = false
    /// Currently selected point in path edit mode
    @State private var selectedPointID: UUID? = nil

    public init(document: DesignDocument) {
        self.document = document
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background (infinite area)
                canvasBackground
                    .gesture(panGesture)

                // Phone frame centered
                if let page = document.selectedPage {
                    phoneFrame(for: page)
                        .scaleEffect(scale)
                        .offset(offset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .gesture(magnificationGesture)
            .onKeyPress(.tab) {
                handleTabKey()
                return .handled
            }
            .onKeyPress(.escape) {
                if isEditingPath {
                    isEditingPath = false
                    selectedPointID = nil
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                if isEditingPath, let pointID = selectedPointID,
                   let elementID = document.selectedElementID {
                    document.updateElement(elementID) { node in
                        if case .vectorPath(var path, let stroke, let fill) = node.payload {
                            path.points.removeAll { $0.id == pointID }
                            node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                        }
                    }
                    selectedPointID = nil
                    return .handled
                }
                return .ignored
            }
            .overlay(alignment: .bottomTrailing) {
                canvasControls
            }
            .overlay(alignment: .bottomLeading) {
                snapControls
            }
            // Show edit mode indicator
            .overlay(alignment: .top) {
                if isEditingPath {
                    editModeIndicator
                }
            }
        }
    }

    // MARK: - Canvas Background

    private var canvasBackground: some View {
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
        .onTapGesture {
            document.selectedElementID = nil
            isEditingPath = false
            selectedPointID = nil
        }
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
                if showGrid || (snapSettings.isEnabled && snapSettings.showGuides) {
                    GridOverlay(
                        deviceSize: page.deviceFrame.size,
                        gridSize: snapSettings.isEnabled ? snapSettings.mode.gridSize : 8,
                        showGrid: showGrid || snapSettings.isEnabled,
                        snapMode: snapSettings.isEnabled ? snapSettings.mode : nil,
                        safeAreaInsets: page.deviceFrame.safeAreaInsets
                    )
                }

                // Element tree
                ElementRenderer(
                    node: page.rootElement,
                    selectedID: document.selectedElementID,
                    snapSettings: snapSettings,
                    isRoot: true,
                    isEditingPath: $isEditingPath,
                    selectedPointID: $selectedPointID,
                    document: document,
                    onSelect: { id in
                        document.selectedElementID = id
                        // Exit path edit if selecting a different element
                        if isEditingPath && id != document.selectedElementID {
                            isEditingPath = false
                            selectedPointID = nil
                        }
                    },
                    onMove: { id, x, y in
                        document.updateElement(id) { node in
                            // Remove existing offset modifier
                            node.modifiers.removeAll { mod in
                                if case .offset = mod { return true }
                                return false
                            }
                            // Add new offset (only if non-zero)
                            if abs(x) > 0.5 || abs(y) > 0.5 {
                                node.modifiers.append(.offset(x: x, y: y))
                            }
                        }
                    }
                )
            }
        }
        .gesture(panGesture)
    }

    // MARK: - Gestures

    /// Pan canvas: Alt+drag (Option key held)
    private var panGesture: some Gesture {
        DragGesture()
            .modifiers(.option)
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

    // MARK: - Canvas Controls (bottom-right)

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
            .help("Reset view")

            Button {
                showGrid.toggle()
            } label: {
                Image(systemName: showGrid ? "grid.circle.fill" : "grid.circle")
            }
            .help("Toggle grid")
        }
        .buttonStyle(.borderless)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    // MARK: - Tab Key / Edit Mode

    private func handleTabKey() {
        guard let elementID = document.selectedElementID,
              let pageID = document.selectedPageID,
              let page = document.pages.first(where: { $0.id == pageID }),
              let element = page.rootElement.find(by: elementID) else {
            isEditingPath = false
            return
        }
        // Only enter edit mode for vector paths
        if case .vectorPath = element.payload {
            isEditingPath.toggle()
            if !isEditingPath {
                selectedPointID = nil
            }
        }
    }

    private var editModeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.and.outline")
                .font(.caption)
            Text("Edit Mode")
                .font(.caption.weight(.medium))
            Text("— Tab to exit, Click to add points, Delete to remove")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Snap Controls (bottom-left)

    private var snapControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $snapSettings.isEnabled) {
                Label("Snap", systemImage: "arrow.down.right.and.arrow.up.left")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)

            if snapSettings.isEnabled {
                Picker("", selection: $snapSettings.mode) {
                    ForEach(SnapMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Toggle(isOn: $snapSettings.showGuides) {
                    Text("Show guides")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
