import SwiftUI
import DesignModel

/// Recursively renders an ElementNode tree as SwiftUI views on the canvas.
/// Supports selection, drag-to-move, and visual modifier application.
public struct ElementRenderer: View {
    let node: ElementNode
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onMove: (UUID, CGFloat, CGFloat) -> Void
    let snapSettings: SnapSettings
    let isRoot: Bool

    // Path editing state (passed down from CanvasView)
    @Binding var isEditingPath: Bool
    @Binding var selectedPointID: UUID?
    var document: DesignDocument?

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    public init(
        node: ElementNode,
        selectedID: UUID? = nil,
        snapSettings: SnapSettings = SnapSettings(),
        isRoot: Bool = true,
        isEditingPath: Binding<Bool> = .constant(false),
        selectedPointID: Binding<UUID?> = .constant(nil),
        document: DesignDocument? = nil,
        onSelect: @escaping (UUID) -> Void = { _ in },
        onMove: @escaping (UUID, CGFloat, CGFloat) -> Void = { _, _, _ in }
    ) {
        self.node = node
        self.selectedID = selectedID
        self.snapSettings = snapSettings
        self.isRoot = isRoot
        self._isEditingPath = isEditingPath
        self._selectedPointID = selectedPointID
        self.document = document
        self.onSelect = onSelect
        self.onMove = onMove
    }

    /// Whether this node is a vector path
    private var isVectorPath: Bool {
        if case .vectorPath = node.payload { return true }
        return false
    }

    /// Get the element's frame size from its modifiers (for overlay sizing)
    private var elementFrameSize: CGSize {
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

    /// Stored offset from the node's modifiers (separate from live drag offset)
    private var storedOffset: CGSize {
        for mod in node.modifiers {
            if case .offset(let x, let y) = mod {
                return CGSize(width: x, height: y)
            }
        }
        return .zero
    }

    public var body: some View {
        if node.isVisible {
            if isRoot {
                // Root element must fill the full proposed size (phone frame)
                // so that children at any offset position remain interactive.
                renderPayload()
                    .applyModifiers(node.modifiers.filter { mod in
                        if case .offset = mod { return false }
                        return true
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .id(node.id)
            } else {
                let isThisEditing = isEditingPath && selectedID == node.id && isVectorPath
                renderPayload()
                    .applyModifiers(node.modifiers.filter { mod in
                        if case .offset = mod { return false }
                        return true
                    })
                    .contentShape(Rectangle())
                    .overlay {
                        if selectedID == node.id && !isThisEditing {
                            SelectionOverlay()
                        }
                    }
                    .overlay {
                        if isThisEditing, let doc = document {
                            PathEditingOverlay(
                                elementID: node.id,
                                document: doc,
                                selectedPointID: $selectedPointID,
                                isEditingPath: $isEditingPath,
                                frameSize: elementFrameSize
                            )
                        }
                    }
                    // Apply stored offset + live drag offset together so overlay follows
                    .offset(CGSize(
                        width: storedOffset.width + dragOffset.width,
                        height: storedOffset.height + dragOffset.height
                    ))
                    .conditionalDragGesture(isEnabled: !isThisEditing, gesture: elementDragGesture)
                    .onTapGesture(count: 2) {
                        // Double-click to enter edit mode on vector paths
                        if isVectorPath && !isEditingPath {
                            onSelect(node.id)
                            isEditingPath = true
                        }
                    }
                    .onTapGesture {
                        if !isThisEditing {
                            onSelect(node.id)
                        }
                    }
                    .id(node.id)
            }
        }
    }

    // MARK: - Element Drag Gesture

    private var elementDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !node.isLocked && !isRoot else { return }
                isDragging = true
                var newX = value.translation.width
                var newY = value.translation.height
                if snapSettings.isEnabled {
                    newX = snapSettings.snap(newX)
                    newY = snapSettings.snap(newY)
                }
                dragOffset = CGSize(width: newX, height: newY)
                // Select on drag start
                onSelect(node.id)
            }
            .onEnded { value in
                guard !node.isLocked && !isRoot else { return }
                isDragging = false

                // Get current offset from modifiers
                var currentX: CGFloat = 0
                var currentY: CGFloat = 0
                for mod in node.modifiers {
                    if case .offset(let x, let y) = mod {
                        currentX = x
                        currentY = y
                    }
                }

                var finalX = currentX + value.translation.width
                var finalY = currentY + value.translation.height
                if snapSettings.isEnabled {
                    finalX = snapSettings.snap(finalX)
                    finalY = snapSettings.snap(finalY)
                }

                // Commit the move
                onMove(node.id, finalX, finalY)
                dragOffset = .zero
            }
    }

    // MARK: - Payload Rendering

    @ViewBuilder
    private func renderPayload() -> some View {
        switch node.payload {
        // Layout
        case .vStack(let spacing, let alignment):
            VStack(alignment: alignment.swiftUIValue, spacing: spacing) {
                renderChildren()
            }
        case .hStack(let spacing, let alignment):
            HStack(alignment: alignment.swiftUIValue, spacing: spacing) {
                renderChildren()
            }
        case .zStack(let alignment):
            ZStack(alignment: alignment.swiftUIValue) {
                renderChildren()
            }
        case .scrollView(let axis):
            ScrollView(axis == .vertical ? .vertical : .horizontal) {
                if axis == .vertical {
                    VStack { renderChildren() }
                } else {
                    HStack { renderChildren() }
                }
            }
        case .lazyVGrid(let columns, let spacing):
            LazyVGrid(columns: columns.map { $0.swiftUIGridItem }, spacing: spacing) {
                renderChildren()
            }
        case .lazyHGrid(let rows, let spacing):
            LazyHGrid(rows: rows.map { $0.swiftUIGridItem }, spacing: spacing) {
                renderChildren()
            }

        // Content
        case .text(let content, let style):
            if let style {
                Text(content).font(style.swiftUIFont)
            } else {
                Text(content)
            }
        case .image(let systemName, let assetName):
            if let systemName {
                Image(systemName: systemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let assetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .rectangle:
            Rectangle()
        case .circle:
            Circle()
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: radius)
        case .capsule:
            Capsule()
        case .spacer(let minLength):
            Spacer(minLength: minLength)
        case .divider:
            Divider()
        case .color(let designColor):
            designColor.swiftUIColor

        // Navigation — render with Liquid Glass approximation
        case .navigationStack(let title, _):
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(.largeTitle).bold()
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect)
                renderChildren()
                Spacer()
            }
        case .tabView(let tabs):
            VStack(spacing: 0) {
                ZStack {
                    renderChildren()
                }
                .frame(maxHeight: .infinity)
                // Floating Liquid Glass tab bar
                HStack {
                    ForEach(tabs) { tab in
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 20))
                            Text(tab.title)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            }
        case .sheet:
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .overlay {
                    VStack { renderChildren() }
                }

        // Controls
        case .button(let title, let style):
            switch style {
            case .borderedProminent:
                Button(title) {}.buttonStyle(.borderedProminent)
            case .bordered:
                Button(title) {}.buttonStyle(.bordered)
            case .borderless:
                Button(title) {}.buttonStyle(.borderless)
            case .plain:
                Button(title) {}.buttonStyle(.plain)
            case .automatic:
                Button(title) {}.buttonStyle(.automatic)
            case .glass:
                Button(title) {}.buttonStyle(.glass)
            case .glassProminent:
                Button(title) {}.buttonStyle(.glassProminent)
            }
        case .textField(let placeholder):
            TextField(placeholder, text: .constant(""))
                .textFieldStyle(.roundedBorder)
        case .secureField(let placeholder):
            SecureField(placeholder, text: .constant(""))
                .textFieldStyle(.roundedBorder)
        case .toggle(let label, let isOn):
            Toggle(label, isOn: .constant(isOn))
        case .slider(let minValue, let maxValue, let value):
            Slider(value: .constant(value), in: minValue...maxValue)
        case .picker(let label, let options, let selection):
            Picker(label, selection: .constant(selection)) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
        case .stepper(let label, let minValue, let maxValue, let value):
            Stepper(label, value: .constant(value), in: minValue...maxValue)
        case .datePicker(let label):
            DatePicker(label, selection: .constant(Date()))
        case .progressView(let style, let value):
            if style == .circular {
                if let value {
                    ProgressView(value: value).progressViewStyle(.circular)
                } else {
                    ProgressView().progressViewStyle(.circular)
                }
            } else {
                if let value {
                    ProgressView(value: value).progressViewStyle(.linear)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            }
        case .label(let title, let systemImage):
            Label(title, systemImage: systemImage)

        // Containers
        case .list:
            List {
                renderChildren()
            }
        case .form:
            Form {
                renderChildren()
            }
        case .group:
            Group {
                renderChildren()
            }

        // Vector Drawing
        case .vectorPath(let path, let stroke, let fill):
            VectorPathView(path: path, stroke: stroke, fill: fill)

        // Imported Image
        case .importedImage(let data):
            ImportedImageView(imageData: data)
        }
    }

    @ViewBuilder
    private func renderChildren() -> some View {
        ForEach(node.children) { child in
            ElementRenderer(
                node: child,
                selectedID: selectedID,
                snapSettings: snapSettings,
                isRoot: false,
                isEditingPath: $isEditingPath,
                selectedPointID: $selectedPointID,
                document: document,
                onSelect: onSelect,
                onMove: onMove
            )
        }
    }
}

// MARK: - Car Paint Material View

/// 3-layer physically-inspired car paint material.
/// Layer 1: Base coat with tilt-reactive color shift
/// Layer 2: Metallic flake with variable size and density
/// Layer 3: Clearcoat with sharp moving specular
struct CarPaintMaterialView: View {
    let config: CarPaintConfig
    @StateObject private var motion = MotionManager()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let tx = motion.tiltX
            let ty = motion.tiltY

            Canvas { context, size in
                // ── Layer 1: Base coat with tilt-dependent color shift ──
                let baseRect = CGRect(origin: .zero, size: size)
                context.fill(Path(baseRect), with: .color(config.baseColor.swiftUIColor))

                // Darken away from light source for depth
                let darkGrad = Gradient(stops: [
                    .init(color: Color.black.opacity(0.0), location: 0.0),
                    .init(color: Color.black.opacity(0.25), location: 1.0),
                ])
                let lightCenter = CGPoint(
                    x: w * (0.5 + tx * 0.35),
                    y: h * (0.35 + ty * 0.3)
                )
                context.fill(
                    Path(baseRect),
                    with: .radialGradient(
                        darkGrad,
                        center: lightCenter,
                        startRadius: 0,
                        endRadius: max(w, h) * 0.9
                    )
                )

                // Subtle warm highlight near light (color shift)
                let warmGrad = Gradient(stops: [
                    .init(color: Color.white.opacity(0.08), location: 0.0),
                    .init(color: Color.clear, location: 1.0),
                ])
                context.fill(
                    Path(baseRect),
                    with: .radialGradient(
                        warmGrad,
                        center: lightCenter,
                        startRadius: 0,
                        endRadius: max(w, h) * 0.5
                    )
                )

                // ── Layer 2: Metallic flake ──
                // flakeScale controls SIZE of each flake (0=tiny, 1=large)
                // flakeIntensity controls BRIGHTNESS/density
                let flakeMinSize: CGFloat = 0.3 + config.flakeScale * 3.5  // 0.3pt to 3.8pt
                let flakeMaxSize: CGFloat = flakeMinSize * 1.8
                let flakeCount = 800  // Fixed density grid
                let intensity = config.flakeIntensity

                if intensity > 0.01 {
                    for i in 0..<flakeCount {
                        // Golden ratio quasi-random distribution (deterministic)
                        let phi1 = Double(i) * 0.6180339887498949
                        let phi2 = Double(i) * 0.4142135623730951
                        let phi3 = Double(i) * 0.7320508075688772  // sqrt(3)-1 for size variation
                        let fx = CGFloat(phi1 - phi1.rounded(.down)) * size.width
                        let fy = CGFloat(phi2 - phi2.rounded(.down)) * size.height
                        let sizeVar = CGFloat(phi3 - phi3.rounded(.down))

                        // Each flake has a "normal" direction — catches light at specific angles
                        let flakeAngleX = (phi1.truncatingRemainder(dividingBy: 1.0) - 0.5) * 2.0
                        let flakeAngleY = (phi2.truncatingRemainder(dividingBy: 0.7) / 0.7 - 0.5) * 2.0

                        // Dot product with light direction = how much this flake catches light
                        let dot = flakeAngleX * tx + flakeAngleY * ty
                        let catchLight = max(0, dot * 0.6 + 0.3)  // bias so some always visible

                        let brightness = catchLight * intensity * (0.4 + sizeVar * 0.6)

                        if brightness > 0.02 {
                            let s = flakeMinSize + (flakeMaxSize - flakeMinSize) * sizeVar
                            let rect = CGRect(x: fx - s/2, y: fy - s/2, width: s, height: s)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(Color.white.opacity(brightness * 0.5))
                            )
                        }
                    }
                }

                // ── Layer 3: Clearcoat specular ──
                // Primary specular — broad, soft
                let spec1Center = CGPoint(
                    x: w * (0.5 + tx * 0.5),
                    y: h * (0.3 + ty * 0.4)
                )
                let spec1Radius = max(w, h) * (0.6 - config.clearcoatSharpness * 0.35)
                let spec1Grad = Gradient(stops: [
                    .init(color: Color.white.opacity(config.clearcoatIntensity * 0.25), location: 0.0),
                    .init(color: Color.white.opacity(config.clearcoatIntensity * 0.05), location: 0.6),
                    .init(color: Color.clear, location: 1.0),
                ])
                context.fill(
                    Path(baseRect),
                    with: .radialGradient(spec1Grad, center: spec1Center, startRadius: 0, endRadius: spec1Radius)
                )

                // Secondary specular — tight, sharp (clearcoat "pinpoint")
                let spec2Center = CGPoint(
                    x: w * (0.48 + tx * 0.55),
                    y: h * (0.25 + ty * 0.45)
                )
                let spec2Radius = max(w, h) * (0.2 - config.clearcoatSharpness * 0.12)
                let spec2Grad = Gradient(stops: [
                    .init(color: Color.white.opacity(config.clearcoatIntensity * config.clearcoatSharpness * 0.6), location: 0.0),
                    .init(color: Color.white.opacity(config.clearcoatIntensity * 0.08), location: 0.5),
                    .init(color: Color.clear, location: 1.0),
                ])
                context.fill(
                    Path(baseRect),
                    with: .radialGradient(spec2Grad, center: spec2Center, startRadius: 0, endRadius: spec2Radius)
                )

                // ── Layer 4: Fresnel rim ──
                if config.fresnelIntensity > 0 {
                    // Top edge
                    let topGrad = Gradient(colors: [
                        Color.white.opacity(config.fresnelIntensity * 0.2),
                        Color.clear
                    ])
                    let topRect = CGRect(x: 0, y: 0, width: size.width, height: min(size.height * 0.15, 20))
                    context.fill(
                        Path(topRect),
                        with: .linearGradient(topGrad, startPoint: .zero, endPoint: CGPoint(x: 0, y: topRect.height))
                    )

                    // Bottom edge
                    let botY = size.height - min(size.height * 0.1, 12)
                    let botRect = CGRect(x: 0, y: botY, width: size.width, height: size.height - botY)
                    let botGrad = Gradient(colors: [Color.clear, Color.white.opacity(config.fresnelIntensity * 0.12)])
                    context.fill(
                        Path(botRect),
                        with: .linearGradient(botGrad, startPoint: CGPoint(x: 0, y: botY), endPoint: CGPoint(x: 0, y: size.height))
                    )

                    // Side edges
                    let sideW: CGFloat = min(size.width * 0.08, 8)
                    let leftRect = CGRect(x: 0, y: 0, width: sideW, height: size.height)
                    let leftGrad = Gradient(colors: [Color.white.opacity(config.fresnelIntensity * 0.1), Color.clear])
                    context.fill(
                        Path(leftRect),
                        with: .linearGradient(leftGrad, startPoint: .zero, endPoint: CGPoint(x: sideW, y: 0))
                    )
                    let rightRect = CGRect(x: size.width - sideW, y: 0, width: sideW, height: size.height)
                    let rightGrad = Gradient(colors: [Color.clear, Color.white.opacity(config.fresnelIntensity * 0.1)])
                    context.fill(
                        Path(rightRect),
                        with: .linearGradient(rightGrad, startPoint: CGPoint(x: size.width - sideW, y: 0), endPoint: CGPoint(x: size.width, y: 0))
                    )
                }
            }
        }
    }
}

// MARK: - Motion Manager (Core Motion for device tilt)

import Combine

#if canImport(CoreMotion)
import CoreMotion
#endif

class MotionManager: ObservableObject {
    @Published var tiltX: Double = 0.0
    @Published var tiltY: Double = 0.0

    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    #endif

    // Mouse tracking for macOS preview
    private var mouseTracker: Any? = nil

    init() {
        startMotionUpdates()
    }

    private func startMotionUpdates() {
        #if canImport(CoreMotion) && os(iOS)
        guard manager.isDeviceMotionAvailable else {
            startMouseTracking()
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            withAnimation(.interactiveSpring) {
                self?.tiltX = motion.gravity.x
                self?.tiltY = motion.gravity.y
            }
        }
        #else
        startMouseTracking()
        #endif
    }

    private func startMouseTracking() {
        #if os(macOS)
        // On macOS, use mouse position as tilt proxy for live preview
        mouseTracker = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let screen = NSScreen.main else { return event }
            let pos = event.locationInWindow
            let screenSize = screen.frame.size
            DispatchQueue.main.async {
                self?.tiltX = (pos.x / screenSize.width - 0.5) * 2.0
                self?.tiltY = (pos.y / screenSize.height - 0.5) * -2.0
            }
            return event
        }
        #endif
    }

    deinit {
        #if canImport(CoreMotion) && os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
        #if os(macOS)
        if let tracker = mouseTracker {
            NSEvent.removeMonitor(tracker)
        }
        #endif
    }
}

// MARK: - Conditional Gesture

extension View {
    @ViewBuilder
    func conditionalDragGesture<G: Gesture>(isEnabled: Bool, gesture: G) -> some View {
        if isEnabled {
            self.gesture(gesture)
        } else {
            self
        }
    }
}

// MARK: - Modifier Application

extension View {
    func applyModifiers(_ modifiers: [DesignModifier]) -> some View {
        var view = AnyView(self)
        for modifier in modifiers {
            view = AnyView(view.applyModifier(modifier))
        }
        return view
    }

    @ViewBuilder
    func applyModifier(_ modifier: DesignModifier) -> some View {
        switch modifier {
        case .frame(let width, let height, let minWidth, let maxWidth, let minHeight, let maxHeight, let alignment):
            self.frame(
                minWidth: minWidth, idealWidth: nil, maxWidth: maxWidth,
                minHeight: minHeight, idealHeight: nil, maxHeight: maxHeight,
                alignment: (alignment ?? .center).swiftUIValue
            )
            .frame(width: width, height: height)

        case .padding(let edges, let amount):
            self.padding(edges.swiftUIValue, amount)

        case .foregroundStyle(let color):
            self.foregroundStyle(color.swiftUIColor)

        case .background(let color):
            self.background(color.swiftUIColor)

        case .backgroundMaterial(let material):
            self.background(material.swiftUIMaterial)

        case .tint(let color):
            self.tint(color.swiftUIColor)

        case .opacity(let opacity):
            self.opacity(opacity)

        case .font(let style, let size, let weight, let design):
            self.font(Self.buildFont(style: style, size: size, weight: weight, design: design))

        case .multilineTextAlignment(let alignment):
            self.multilineTextAlignment(alignment.swiftUITextAlignment)

        case .lineLimit(let limit):
            self.lineLimit(limit)

        case .lineSpacing(let spacing):
            self.lineSpacing(spacing)

        case .cornerRadius(let radius):
            self.clipShape(RoundedRectangle(cornerRadius: radius))

        case .shadow(let color, let radius, let x, let y):
            self.shadow(color: color.swiftUIColor, radius: radius, x: x, y: y)

        case .blur(let radius):
            self.blur(radius: radius)

        case .glassEffect(let style):
            // Real macOS 26 Liquid Glass
            switch style {
            case .regular:
                self.glassEffect(.regular, in: .capsule)
            case .clear:
                self.glassEffect(.clear, in: .capsule)
            case .identity:
                self.glassEffect(.identity, in: .capsule)
            }

        case .glassConfig(let config):
            // Full Liquid Glass config with tint, interactivity, shape
            self.applyGlassConfig(config)

        case .glassEffectContainer:
            self.glassEffect(.regular, in: .capsule)

        case .carPaint(let config):
            self.overlay(CarPaintMaterialView(config: config))

        case .offset(let x, let y):
            self.offset(x: x, y: y)

        case .rotationEffect(let degrees):
            self.rotationEffect(.degrees(degrees))

        case .scaleEffect(let x, let y):
            self.scaleEffect(x: x, y: y)

        case .zIndex(let index):
            self.zIndex(index)

        case .disabled(let isDisabled):
            self.disabled(isDisabled)

        case .clipShape(let shape):
            switch shape {
            case .rectangle: AnyView(self.clipShape(Rectangle()))
            case .roundedRectangle: AnyView(self.clipShape(RoundedRectangle(cornerRadius: 8)))
            case .circle: AnyView(self.clipShape(Circle()))
            case .capsule: AnyView(self.clipShape(Capsule()))
            case .ellipse: AnyView(self.clipShape(Ellipse()))
            }

        case .layoutPriority(let priority):
            self.layoutPriority(priority)

        default:
            self
        }
    }

    private static func buildFont(
        style: TextStyleType?,
        size: CGFloat?,
        weight: FontWeightType?,
        design: FontDesignType?
    ) -> Font {
        if let style {
            return style.swiftUIFont
        }
        let baseSize = size ?? 17
        return .system(
            size: baseSize,
            weight: weight?.swiftUIValue ?? .regular,
            design: design?.swiftUIValue ?? .default
        )
    }

    // MARK: - Real Liquid Glass helpers

    /// Apply a full GlassConfig using the real macOS 26 `.glassEffect()` API.
    @ViewBuilder
    func applyGlassConfig(_ config: GlassConfig) -> some View {
        let glass = Self.buildGlass(config)
        switch config.shape {
        case .capsule:
            self.glassEffect(glass, in: .capsule)
        case .circle:
            self.glassEffect(glass, in: .circle)
        case .roundedRectangle:
            self.glassEffect(glass, in: .rect(cornerRadius: 12))
        case .rectangle:
            self.glassEffect(glass, in: .rect)
        case .ellipse:
            self.glassEffect(glass, in: .ellipse)
        }
    }

    /// Build a `Glass` value from our config, with tint + interactive chaining.
    private static func buildGlass(_ config: GlassConfig) -> Glass {
        var glass: Glass
        switch config.style {
        case .regular: glass = .regular
        case .clear: glass = .clear
        case .identity: glass = .identity
        }
        if let tint = config.tintColor {
            glass = glass.tint(tint.swiftUIColor.opacity(config.tintIntensity))
        }
        if config.isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}
