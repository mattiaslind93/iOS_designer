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

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    public init(
        node: ElementNode,
        selectedID: UUID? = nil,
        snapSettings: SnapSettings = SnapSettings(),
        isRoot: Bool = true,
        onSelect: @escaping (UUID) -> Void = { _ in },
        onMove: @escaping (UUID, CGFloat, CGFloat) -> Void = { _, _, _ in }
    ) {
        self.node = node
        self.selectedID = selectedID
        self.snapSettings = snapSettings
        self.isRoot = isRoot
        self.onSelect = onSelect
        self.onMove = onMove
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
            renderPayload()
                .applyModifiers(node.modifiers.filter { mod in
                    if case .offset = mod { return false }
                    return true
                })
                .contentShape(Rectangle())
                .overlay {
                    if selectedID == node.id {
                        SelectionOverlay()
                    }
                }
                // Apply stored offset + live drag offset together so overlay follows
                .offset(CGSize(
                    width: storedOffset.width + dragOffset.width,
                    height: storedOffset.height + dragOffset.height
                ))
                .gesture(elementDragGesture)
                .onTapGesture {
                    onSelect(node.id)
                }
                .id(node.id)
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
                .background(GlassBackgroundView())
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
                .background(GlassBackgroundView())
                .clipShape(Capsule())
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
        case .button(let title, _):
            Button(title) {}
                .buttonStyle(.borderedProminent)
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
                onSelect: onSelect,
                onMove: onMove
            )
        }
    }
}

// MARK: - Glass Background View (Liquid Glass approximation on macOS)

/// Approximates iOS 26 Liquid Glass on macOS canvas.
/// Uses layered translucent materials — no solid colored rectangles.
struct GlassBackgroundView: View {
    var style: GlassStyleType = .regular
    var config: GlassConfig? = nil

    private var effectiveStyle: GlassStyleType {
        config?.style ?? style
    }
    private var tintColor: Color? {
        config?.tintColor?.swiftUIColor
    }

    var body: some View {
        if effectiveStyle == .identity {
            Color.clear
        } else {
            ZStack {
                // Layer 1: Frosted backdrop blur (the core of Liquid Glass)
                // "clear" = more transparent, "regular" = more frosted
                if effectiveStyle == .clear {
                    Color.white.opacity(0.06)
                        .background(.ultraThinMaterial)
                } else {
                    Color.clear
                        .background(.thinMaterial)
                }

                // Layer 2: Subtle light-bending gradient (lensing effect)
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(effectiveStyle == .clear ? 0.08 : 0.15), location: 0.0),
                        .init(color: Color.white.opacity(0.02), location: 0.4),
                        .init(color: Color.white.opacity(effectiveStyle == .clear ? 0.04 : 0.08), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Layer 3: Specular top-edge highlight (responds to light angle)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(effectiveStyle == .clear ? 0.15 : 0.3),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 2)
                    Spacer()
                }

                // Layer 4: Tint color (semantic, like .glassEffect(.regular.tint(.orange)))
                if let tint = tintColor {
                    tint.opacity(0.15)
                }

                // Layer 5: Subtle inner border for edge definition
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        }
    }
}

// MARK: - Car Paint Material View

/// Renders a 3-layer metallic car paint material:
/// 1. Base coat (deep color with subtle variation)
/// 2. Metallic flake layer (sparkle noise)
/// 3. Clearcoat (sharp specular highlight that follows device tilt)
struct CarPaintMaterialView: View {
    let config: CarPaintConfig
    @StateObject private var motion = MotionManager()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let tiltX = motion.tiltX
            let tiltY = motion.tiltY

            ZStack {
                // Layer 1: Base coat — deep color with subtle metallic variation
                config.baseColor.swiftUIColor

                // Metallic color shift based on viewing angle (tilt)
                RadialGradient(
                    colors: [
                        config.baseColor.swiftUIColor.opacity(0.0),
                        config.baseColor.swiftUIColor.opacity(0.3),
                    ],
                    center: UnitPoint(
                        x: 0.5 + tiltX * 0.3,
                        y: 0.5 + tiltY * 0.3
                    ),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.8
                )

                // Layer 2: Metallic flake — high frequency sparkle
                Canvas { context, canvasSize in
                    let flakeCount = Int(config.flakeScale * 200 + 50)
                    let intensity = config.flakeIntensity

                    for i in 0..<flakeCount {
                        // Deterministic pseudo-random positions
                        let seed1 = Double(i) * 0.618033988749895
                        let seed2 = Double(i) * 0.414213562373095
                        let fx = (seed1 - Double(Int(seed1))) * canvasSize.width
                        let fy = (seed2 - Double(Int(seed2))) * canvasSize.height

                        // Flake brightness depends on angle to light (tilt)
                        let dx = fx / canvasSize.width - 0.5 - tiltX * 0.4
                        let dy = fy / canvasSize.height - 0.5 - tiltY * 0.4
                        let dist = sqrt(dx * dx + dy * dy)
                        let brightness = max(0, 1.0 - dist * 2.5) * intensity

                        if brightness > 0.05 {
                            let flakeSize: CGFloat = CGFloat.random(in: 0.5...2.0)
                            let rect = CGRect(x: fx, y: fy, width: flakeSize, height: flakeSize)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(Color.white.opacity(brightness * 0.6))
                            )
                        }
                    }
                }
                .blendMode(.screen)

                // Layer 3: Clearcoat — sharp specular highlight that tracks tilt
                let specX = 0.5 + tiltX * 0.6
                let specY = 0.3 + tiltY * 0.5
                RadialGradient(
                    colors: [
                        Color.white.opacity(config.clearcoatIntensity * 0.7),
                        Color.white.opacity(config.clearcoatIntensity * 0.15),
                        Color.clear,
                    ],
                    center: UnitPoint(x: specX, y: specY),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * (1.0 - config.clearcoatSharpness * 0.6)
                )
                .blendMode(.screen)

                // Fresnel edge brightening
                if config.fresnelIntensity > 0 {
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(config.fresnelIntensity * 0.3),
                                    Color.white.opacity(config.fresnelIntensity * 0.15),
                                    Color.white.opacity(config.fresnelIntensity * 0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
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
            // Liquid Glass approximation on macOS canvas
            self.background(GlassBackgroundView(style: style))

        case .glassConfig(let config):
            self.background(GlassBackgroundView(config: config))

        case .glassEffectContainer:
            self.background(GlassBackgroundView())

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
}
