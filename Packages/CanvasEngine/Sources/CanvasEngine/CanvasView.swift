import SwiftUI
import DesignModel
import AppKit

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

    /// Canvas must be focusable to receive key events
    @FocusState private var canvasFocused: Bool

    /// NSEvent monitor for reliable key handling (Tab is eaten by focus system)
    @State private var keyMonitor: Any? = nil

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
            .focusable()
            .focused($canvasFocused)
            .focusEffectDisabled()
            .gesture(magnificationGesture)
            .onAppear {
                canvasFocused = true
                setupKeyMonitor()
            }
            .onDisappear {
                removeKeyMonitor()
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
            canvasFocused = true
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
                        // Exit path edit if selecting a different element
                        if isEditingPath && id != document.selectedElementID {
                            isEditingPath = false
                            selectedPointID = nil
                        }
                        document.selectedElementID = id
                        canvasFocused = true
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

                // Path editing overlay — rendered on top of everything in the
                // phone frame so handles outside the element bounds are visible
                // and interactive.
                if isEditingPath, let elementID = document.selectedElementID {
                    PathEditingOverlay(
                        elementID: elementID,
                        document: document,
                        selectedPointID: $selectedPointID,
                        isEditingPath: $isEditingPath,
                        elementOffset: editingElementOffset(in: page)
                    )
                    .allowsHitTesting(true)
                }
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

    // MARK: - Editing Element Helpers

    /// Get the offset of the currently-edited element so the overlay
    /// can position points correctly within the phone frame coordinate space.
    private func editingElementOffset(in page: DesignPage) -> CGPoint {
        guard let elementID = document.selectedElementID,
              let element = page.rootElement.find(by: elementID) else {
            return .zero
        }
        for mod in element.modifiers {
            if case .offset(let x, let y) = mod {
                return CGPoint(x: x, y: y)
            }
        }
        return .zero
    }

    // MARK: - Key Monitor (NSEvent)

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cmd = event.modifierFlags.contains(.command)
            let shift = event.modifierFlags.contains(.shift)

            // ⌘Z = Undo, ⌘⇧Z = Redo
            if cmd && event.keyCode == 6 { // Z key
                if shift {
                    document.redo()
                } else {
                    document.undo()
                }
                return nil
            }

            // ⌘C = Copy
            if cmd && event.keyCode == 8 { // C key
                document.copySelectedElement()
                return nil
            }

            // ⌘V = Paste
            if cmd && event.keyCode == 9 { // V key
                document.pasteElement()
                return nil
            }

            // ⌘X = Cut
            if cmd && event.keyCode == 7 { // X key
                document.cutSelectedElement()
                return nil
            }

            // ⌘D = Duplicate
            if cmd && event.keyCode == 2 { // D key — but only if no shift (shift+D = dark mode toggle)
                if !shift, let elementID = document.selectedElementID {
                    document.duplicateElement(elementID)
                    return nil
                }
            }

            // Tab key (keyCode 48)
            if event.keyCode == 48 {
                handleTabKey()
                return nil
            }

            // Escape key (keyCode 53)
            if event.keyCode == 53 {
                if isEditingPath {
                    if selectedPointID != nil {
                        selectedPointID = nil
                    } else {
                        isEditingPath = false
                    }
                } else {
                    document.selectedElementID = nil
                }
                return nil
            }

            // Delete (keyCode 51 = backspace, 117 = forward delete)
            if event.keyCode == 51 || event.keyCode == 117 {
                if isEditingPath {
                    // Delete selected point in path edit mode
                    if let pointID = selectedPointID,
                       let elementID = document.selectedElementID {
                        document.pushUndo()
                        document.updateElement(elementID) { node in
                            if case .vectorPath(var path, let stroke, let fill) = node.payload {
                                path.points.removeAll { $0.id == pointID }
                                node.payload = .vectorPath(path: path, stroke: stroke, fill: fill)
                            }
                        }
                        selectedPointID = nil
                        return nil
                    }
                } else {
                    // Delete selected element
                    document.deleteSelectedElement()
                    return nil
                }
            }

            return event // pass through
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
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
