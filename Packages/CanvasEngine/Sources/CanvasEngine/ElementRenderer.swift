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

struct GlassBackgroundView: View {
    var style: GlassStyleType = .regular
    var config: GlassConfig? = nil

    private var effectiveBlur: Double {
        config?.blurAmount ?? (style == .ultraThin ? 0.3 : style == .thin ? 0.4 : style == .clear ? 0.2 : 0.5)
    }
    private var effectiveSpecular: Double {
        config?.specularIntensity ?? 0.4
    }
    private var effectiveTint: Double {
        config?.tintIntensity ?? 0.15
    }
    private var effectiveRefraction: Double {
        config?.refractionIntensity ?? 0.5
    }
    private var effectiveShadow: Double {
        config?.shadowIntensity ?? 0.3
    }
    private var tintColor: Color {
        config?.tintColor?.swiftUIColor ?? .white
    }

    var body: some View {
        ZStack {
            // Base material layer
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(effectiveBlur * 2.0)

            // Refraction / distortion approximation
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(effectiveRefraction * 0.4),
                            Color.white.opacity(effectiveRefraction * 0.05),
                            Color.white.opacity(effectiveRefraction * 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Tint layer
            Rectangle()
                .fill(tintColor.opacity(effectiveTint))

            // Top highlight (specular)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(effectiveSpecular * 0.8),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(1, effectiveSpecular * 3))
                Spacer()
            }
        }
        .shadow(color: .black.opacity(effectiveShadow * 0.3), radius: effectiveShadow * 8, x: 0, y: effectiveShadow * 4)
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
