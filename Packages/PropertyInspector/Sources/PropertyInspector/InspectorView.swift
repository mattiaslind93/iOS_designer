import SwiftUI
import DesignModel

/// Property inspector panel that shows editable properties for the selected element.
/// Adapts sections based on the element type.
public struct InspectorView: View {
    @ObservedObject var document: DesignDocument

    public init(document: DesignDocument) {
        self.document = document
    }

    private var selectedElement: ElementNode? {
        guard let pageID = document.selectedPageID,
              let page = document.pages.first(where: { $0.id == pageID }),
              let elementID = document.selectedElementID else { return nil }
        return page.rootElement.find(by: elementID)
    }

    public var body: some View {
        ScrollView {
            if let element = selectedElement {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    inspectorHeader(element)

                    Divider()

                    // Element-specific section
                    ElementSection(element: element, document: document)

                    Divider()

                    // Layout section
                    LayoutSection(element: element, document: document)

                    Divider()

                    // Appearance section
                    AppearanceSection(element: element, document: document)

                    Divider()

                    // Typography section (only for text elements)
                    if element.payload.hasTextProperties {
                        TypographySection(element: element, document: document)
                        Divider()
                    }

                    // Effects section
                    EffectsSection(element: element, document: document)
                }
                .padding(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Select an element to\nedit its properties")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }

    private func inspectorHeader(_ element: ElementNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Image(systemName: element.payload.icon)
                    .foregroundStyle(.secondary)
                TextField("Name", text: Binding(
                    get: { element.name },
                    set: { newName in
                        document.updateElement(element.id) { $0.name = newName }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.callout)
            }
        }
    }
}

// MARK: - Element Section

struct ElementSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    // Local state for text fields — avoids the stale-capture binding issue
    @State private var textContent: String = ""
    @State private var buttonTitle: String = ""
    @State private var sfSymbolName: String = ""
    @State private var toggleLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Element")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            switch element.payload {
            case .text(let content, _):
                LabeledContent("Content") {
                    TextField("Text", text: $textContent)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { textContent = content }
                        .onChange(of: textContent) { _, newValue in
                            document.updateElement(element.id) { node in
                                if case .text(_, let style) = node.payload {
                                    node.payload = .text(content: newValue, style: style)
                                }
                            }
                        }
                        .onChange(of: element.id) { _, _ in
                            if case .text(let c, _) = element.payload { textContent = c }
                        }
                }
            case .button(let title, _):
                LabeledContent("Title") {
                    TextField("Title", text: $buttonTitle)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { buttonTitle = title }
                        .onChange(of: buttonTitle) { _, newValue in
                            document.updateElement(element.id) { node in
                                if case .button(_, let style) = node.payload {
                                    node.payload = .button(title: newValue, style: style)
                                }
                            }
                        }
                        .onChange(of: element.id) { _, _ in
                            if case .button(let t, _) = element.payload { buttonTitle = t }
                        }
                }
            case .image(let systemName, _):
                LabeledContent("SF Symbol") {
                    TextField("Symbol name", text: $sfSymbolName)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { sfSymbolName = systemName ?? "" }
                        .onChange(of: sfSymbolName) { _, newValue in
                            document.updateElement(element.id) { node in
                                node.payload = .image(systemName: newValue.isEmpty ? nil : newValue, assetName: nil)
                            }
                        }
                        .onChange(of: element.id) { _, _ in
                            if case .image(let s, _) = element.payload { sfSymbolName = s ?? "" }
                        }
                }
            case .toggle(let label, let isOn):
                LabeledContent("Label") {
                    TextField("Label", text: $toggleLabel)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { toggleLabel = label }
                        .onChange(of: toggleLabel) { _, newValue in
                            document.updateElement(element.id) { node in
                                node.payload = .toggle(label: newValue, isOn: isOn)
                            }
                        }
                        .onChange(of: element.id) { _, _ in
                            if case .toggle(let l, _) = element.payload { toggleLabel = l }
                        }
                }
            case .textField(let placeholder):
                LabeledContent("Placeholder") {
                    TextField("Placeholder", text: Binding(
                        get: { placeholder },
                        set: { newP in
                            document.updateElement(element.id) { node in
                                node.payload = .textField(placeholder: newP)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .label(let title, let systemImage):
                LabeledContent("Title") {
                    TextField("Label", text: Binding(
                        get: { title },
                        set: { newT in
                            document.updateElement(element.id) { node in
                                node.payload = .label(title: newT, systemImage: systemImage)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Icon") {
                    TextField("SF Symbol", text: Binding(
                        get: { systemImage },
                        set: { newI in
                            document.updateElement(element.id) { node in
                                node.payload = .label(title: title, systemImage: newI)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            default:
                Text(element.payload.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Layout Section

struct LayoutSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layout")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Frame fields
            HStack(spacing: 8) {
                DimensionField(label: "W", value: element.frameWidth) { newValue in
                    document.updateElement(element.id) { node in
                        node.setFrameWidth(newValue)
                    }
                }
                DimensionField(label: "H", value: element.frameHeight) { newValue in
                    document.updateElement(element.id) { node in
                        node.setFrameHeight(newValue)
                    }
                }
            }

            // Size slider (uniform scale)
            if element.frameWidth != nil || element.frameHeight != nil {
                HStack {
                    Text("Size")
                        .font(.callout)
                    Spacer()
                    Slider(
                        value: Binding(
                            get: {
                                let w = element.frameWidth ?? 100
                                let h = element.frameHeight ?? 100
                                return max(w, h)
                            },
                            set: { newSize in
                                document.updateElement(element.id) { node in
                                    let currentW = node.frameWidth ?? 100
                                    let currentH = node.frameHeight ?? 100
                                    let maxDim = max(currentW, currentH)
                                    if maxDim > 0 {
                                        let ratio = newSize / maxDim
                                        node.setFrameWidth(currentW * ratio)
                                        node.setFrameHeight(currentH * ratio)
                                    }
                                }
                            }
                        ),
                        in: 8...500
                    )
                    .frame(width: 120)
                    Text("\(Int(max(element.frameWidth ?? 100, element.frameHeight ?? 100)))")
                        .font(.caption)
                        .frame(width: 36)
                }
            }

            // Padding
            HStack(spacing: 8) {
                DimensionField(label: "Pad", value: element.paddingAmount) { newValue in
                    document.updateElement(element.id) { node in
                        node.setPadding(newValue)
                    }
                }
            }

            // Offset
            HStack(spacing: 8) {
                DimensionField(label: "X", value: element.offsetX) { newValue in
                    document.updateElement(element.id) { node in
                        node.setOffset(x: newValue ?? 0, y: node.offsetY ?? 0)
                    }
                }
                DimensionField(label: "Y", value: element.offsetY) { newValue in
                    document.updateElement(element.id) { node in
                        node.setOffset(x: node.offsetX ?? 0, y: newValue ?? 0)
                    }
                }
            }
        }
    }
}

// MARK: - Appearance Section

struct AppearanceSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Tint color — the single color control
            ColorPickerRow(
                label: "Tint",
                color: element.tintColorValue
            ) { newColor in
                document.updateElement(element.id) { node in
                    node.setTintColor(newColor)
                }
            }

            // Fill mode for shapes
            if element.payload.isShape {
                HStack {
                    Text("Fill")
                        .font(.callout)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { element.fillMode },
                        set: { newMode in
                            document.updateElement(element.id) { node in
                                node.setFillMode(newMode)
                            }
                        }
                    )) {
                        Text("Solid Color").tag(FillMode.solidColor)
                        Text("Car Paint").tag(FillMode.carPaint)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                if element.fillMode == .carPaint {
                    CarPaintSection(element: element, document: document)
                }
            }

            // Opacity
            HStack {
                Text("Opacity")
                    .font(.callout)
                Spacer()
                Slider(
                    value: Binding(
                        get: { element.opacityValue },
                        set: { newValue in
                            document.updateElement(element.id) { node in
                                node.setOpacity(newValue)
                            }
                        }
                    ),
                    in: 0...1
                )
                .frame(width: 120)
                Text("\(Int(element.opacityValue * 100))%")
                    .font(.caption)
                    .frame(width: 36)
            }

            // Corner radius
            HStack {
                Text("Radius")
                    .font(.callout)
                Spacer()
                Slider(
                    value: Binding(
                        get: { element.cornerRadiusValue },
                        set: { newValue in
                            document.updateElement(element.id) { node in
                                node.setCornerRadius(newValue)
                            }
                        }
                    ),
                    in: 0...50
                )
                .frame(width: 120)
                Text("\(Int(element.cornerRadiusValue))")
                    .font(.caption)
                    .frame(width: 36)
            }

            // Visibility & Lock
            HStack {
                Toggle("Visible", isOn: Binding(
                    get: { element.isVisible },
                    set: { newValue in
                        document.updateElement(element.id) { $0.isVisible = newValue }
                    }
                ))
                .toggleStyle(.checkbox)

                Toggle("Locked", isOn: Binding(
                    get: { element.isLocked },
                    set: { newValue in
                        document.updateElement(element.id) { $0.isLocked = newValue }
                    }
                ))
                .toggleStyle(.checkbox)
            }
            .font(.callout)
        }
    }
}

// MARK: - Fill Mode

enum FillMode: String {
    case solidColor
    case carPaint
}

// MARK: - Car Paint Section

struct CarPaintSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    private var config: CarPaintConfig {
        element.carPaintConfig ?? .ferrariRed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Car Paint Material")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Presets
            HStack(spacing: 6) {
                paintPresetButton("Ferrari", config: .ferrariRed)
                paintPresetButton("Midnight", config: .midnightBlue)
                paintPresetButton("Silver", config: .titaniumSilver)
                paintPresetButton("Black", config: .deepBlack)
                paintPresetButton("BRG", config: .britishRacingGreen)
            }

            // Base color
            ColorPickerRow(label: "Base Color", color: config.baseColor) { newColor in
                if let c = newColor {
                    document.updateElement(element.id) { node in
                        var cfg = node.carPaintConfig ?? .ferrariRed
                        cfg.baseColor = c
                        node.setCarPaint(cfg)
                    }
                }
            }

            SliderRow(label: "Flake", value: config.flakeIntensity) { v in
                document.updateElement(element.id) { node in
                    var cfg = node.carPaintConfig ?? .ferrariRed
                    cfg.flakeIntensity = v
                    node.setCarPaint(cfg)
                }
            }

            SliderRow(label: "Flake Size", value: config.flakeScale) { v in
                document.updateElement(element.id) { node in
                    var cfg = node.carPaintConfig ?? .ferrariRed
                    cfg.flakeScale = v
                    node.setCarPaint(cfg)
                }
            }

            SliderRow(label: "Clearcoat", value: config.clearcoatIntensity) { v in
                document.updateElement(element.id) { node in
                    var cfg = node.carPaintConfig ?? .ferrariRed
                    cfg.clearcoatIntensity = v
                    node.setCarPaint(cfg)
                }
            }

            SliderRow(label: "Sharpness", value: config.clearcoatSharpness) { v in
                document.updateElement(element.id) { node in
                    var cfg = node.carPaintConfig ?? .ferrariRed
                    cfg.clearcoatSharpness = v
                    node.setCarPaint(cfg)
                }
            }

            SliderRow(label: "Fresnel", value: config.fresnelIntensity) { v in
                document.updateElement(element.id) { node in
                    var cfg = node.carPaintConfig ?? .ferrariRed
                    cfg.fresnelIntensity = v
                    node.setCarPaint(cfg)
                }
            }

            Toggle("Reacts to Motion", isOn: Binding(
                get: { config.reactsToMotion },
                set: { v in
                    document.updateElement(element.id) { node in
                        var cfg = node.carPaintConfig ?? .ferrariRed
                        cfg.reactsToMotion = v
                        node.setCarPaint(cfg)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    private func paintPresetButton(_ name: String, config preset: CarPaintConfig) -> some View {
        Button {
            document.updateElement(element.id) { node in
                node.setCarPaint(preset)
            }
        } label: {
            Circle()
                .fill(preset.baseColor.swiftUIColor)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    let label: String
    let color: DesignColor?
    let onChange: (DesignColor?) -> Void

    @State private var showPicker = false
    @State private var hexText: String = ""
    @State private var swiftUIColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.callout)
                Spacer()

                // Color swatch
                ColorPicker("", selection: Binding(
                    get: {
                        color?.swiftUIColor ?? .clear
                    },
                    set: { newColor in
                        // Convert SwiftUI Color to DesignColor
                        let nsColor = NSColor(newColor)
                        let r = nsColor.redComponent
                        let g = nsColor.greenComponent
                        let b = nsColor.blueComponent
                        let a = nsColor.alphaComponent
                        onChange(.custom(red: r, green: g, blue: b, opacity: a))
                    }
                ))
                .frame(width: 30)

                // Hex field
                TextField("#RRGGBB", text: Binding(
                    get: {
                        if let c = color {
                            return c.hexString
                        }
                        return ""
                    },
                    set: { hex in
                        if let parsed = DesignColor.fromHex(hex) {
                            onChange(parsed)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .font(.caption.monospaced())
            }

            // System color picker
            if color != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(quickColors, id: \.name) { qc in
                            Circle()
                                .fill(qc.color.swiftUIColor)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                }
                                .onTapGesture {
                                    onChange(qc.color)
                                }
                                .help(qc.name)
                        }
                    }
                }
            }
        }
    }

    private var quickColors: [(name: String, color: DesignColor)] {
        [
            ("Red", .system(.red)),
            ("Orange", .system(.orange)),
            ("Yellow", .system(.yellow)),
            ("Green", .system(.green)),
            ("Mint", .system(.mint)),
            ("Teal", .system(.teal)),
            ("Cyan", .system(.cyan)),
            ("Blue", .system(.blue)),
            ("Indigo", .system(.indigo)),
            ("Purple", .system(.purple)),
            ("Pink", .system(.pink)),
            ("Brown", .system(.brown)),
            ("Gray", .system(.gray)),
            ("Primary", .system(.primary)),
            ("Secondary", .system(.secondary)),
            ("Label", .system(.label)),
            ("Accent", .system(.accentColor)),
            ("White", .custom(red: 1, green: 1, blue: 1, opacity: 1)),
            ("Black", .custom(red: 0, green: 0, blue: 0, opacity: 1)),
        ]
    }
}

// MARK: - Typography Section

struct TypographySection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Typography")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Text style picker
            if case .text(_, let style) = element.payload {
                Picker("Style", selection: Binding(
                    get: { style ?? .body },
                    set: { newStyle in
                        document.updateElement(element.id) { node in
                            if case .text(let content, _) = node.payload {
                                node.payload = .text(content: content, style: newStyle)
                            }
                        }
                    }
                )) {
                    ForEach(TextStyleType.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }

            // Font weight
            Picker("Weight", selection: Binding(
                get: { element.fontWeight ?? .regular },
                set: { newWeight in
                    document.updateElement(element.id) { node in
                        node.setFontWeight(newWeight)
                    }
                }
            )) {
                ForEach(FontWeightType.allCases, id: \.self) { weight in
                    Text(weight.rawValue).tag(weight)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Effects Section

struct EffectsSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effects")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Glass Effect Style
            HStack {
                Text("Glass Effect")
                    .font(.callout)
                Spacer()
                Picker("", selection: Binding(
                    get: { element.glassStyle },
                    set: { newStyle in
                        document.updateElement(element.id) { node in
                            node.setGlassEffect(newStyle)
                        }
                    }
                )) {
                    Text("None").tag(Optional<GlassStyleType>.none)
                    ForEach(GlassStyleType.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(Optional(style))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Liquid Glass detailed controls (shown when glass is active)
            if element.glassStyle != nil {
                GlassConfigSection(element: element, document: document)
            }

            // Shadow
            HStack {
                Text("Shadow")
                    .font(.callout)
                Spacer()
                Slider(
                    value: Binding(
                        get: { element.shadowRadius },
                        set: { newValue in
                            document.updateElement(element.id) { node in
                                node.setShadowRadius(newValue)
                            }
                        }
                    ),
                    in: 0...30
                )
                .frame(width: 120)
                Text("\(Int(element.shadowRadius))")
                    .font(.caption)
                    .frame(width: 36)
            }

            // Shadow color
            if element.shadowRadius > 0 {
                ColorPickerRow(
                    label: "Shadow Color",
                    color: element.shadowColor ?? .custom(red: 0, green: 0, blue: 0, opacity: 0.2)
                ) { newColor in
                    if let c = newColor {
                        document.updateElement(element.id) { node in
                            node.setShadowColor(c)
                        }
                    }
                }
            }

            // Blur
            HStack {
                Text("Blur")
                    .font(.callout)
                Spacer()
                Slider(
                    value: Binding(
                        get: { element.blurRadius },
                        set: { newValue in
                            document.updateElement(element.id) { node in
                                node.setBlurRadius(newValue)
                            }
                        }
                    ),
                    in: 0...30
                )
                .frame(width: 120)
                Text("\(Int(element.blurRadius))")
                    .font(.caption)
                    .frame(width: 36)
            }
        }
    }
}

// MARK: - Liquid Glass Config Section (matches Apple's real API)

struct GlassConfigSection: View {
    let element: ElementNode
    @ObservedObject var document: DesignDocument

    private var config: GlassConfig {
        element.glassConfig ?? .default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Liquid Glass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Shape (in: parameter)
            HStack {
                Text("Shape")
                    .font(.caption)
                Spacer()
                Picker("", selection: Binding(
                    get: { config.shape },
                    set: { newShape in
                        document.updateElement(element.id) { node in
                            var c = node.glassConfig ?? .default
                            c.shape = newShape
                            node.setGlassConfig(c)
                        }
                    }
                )) {
                    ForEach(GlassShapeType.allCases, id: \.self) { shape in
                        Text(shape.rawValue).tag(shape)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }

            // Style (regular vs clear vs identity)
            HStack {
                Text("Style")
                    .font(.caption)
                Spacer()
                Picker("", selection: Binding(
                    get: { config.style },
                    set: { newStyle in
                        document.updateElement(element.id) { node in
                            var c = node.glassConfig ?? .default
                            c.style = newStyle
                            node.setGlassConfig(c)
                        }
                    }
                )) {
                    ForEach(GlassStyleType.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // Tint Color (.tint() modifier on Glass)
            // Apple: "Tint must convey meaning (primary action, state), never decorative"
            ColorPickerRow(
                label: "Tint",
                color: config.tintColor
            ) { newColor in
                document.updateElement(element.id) { node in
                    var c = node.glassConfig ?? .default
                    c.tintColor = newColor
                    node.setGlassConfig(c)
                }
            }

            // Tint Intensity (how saturated/visible the tint color is)
            if config.tintColor != nil {
                SliderRow(
                    label: "Intensity",
                    value: config.tintIntensity,
                    range: 0...1
                ) { newValue in
                    document.updateElement(element.id) { node in
                        var c = node.glassConfig ?? .default
                        c.tintIntensity = newValue
                        node.setGlassConfig(c)
                    }
                }
            }

            // Interactive (.interactive() modifier)
            // Apple: enables press-scale, bounce, shimmer, touch-point illumination
            Toggle("Interactive", isOn: Binding(
                get: { config.isInteractive },
                set: { newValue in
                    document.updateElement(element.id) { node in
                        var c = node.glassConfig ?? .default
                        c.isInteractive = newValue
                        node.setGlassConfig(c)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Slider Row

struct SliderRow: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void

    init(label: String, value: Double, range: ClosedRange<Double> = 0...1, onChange: @escaping (Double) -> Void) {
        self.label = label
        self.value = value
        self.range = range
        self.onChange = onChange
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: range
            )
            .frame(width: 90)
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

// MARK: - Dimension Field

struct DimensionField: View {
    let label: String
    let value: CGFloat?
    let onChange: (CGFloat?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            TextField(
                "Auto",
                text: Binding(
                    get: { value.map { String(Int($0)) } ?? "" },
                    set: { text in
                        onChange(Double(text).map { CGFloat($0) })
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
        }
    }
}

// MARK: - ElementNode Convenience Extensions

extension ElementNode {
    var frameWidth: CGFloat? {
        modifiers.compactMap { if case .frame(let w, _, _, _, _, _, _) = $0 { return w } else { return nil } }.first
    }
    var frameHeight: CGFloat? {
        modifiers.compactMap { if case .frame(_, let h, _, _, _, _, _) = $0 { return h } else { return nil } }.first
    }
    var paddingAmount: CGFloat? {
        modifiers.compactMap { if case .padding(_, let a) = $0 { return a } else { return nil } }.first
    }
    var opacityValue: Double {
        modifiers.compactMap { if case .opacity(let o) = $0 { return o } else { return nil } }.first ?? 1.0
    }
    var cornerRadiusValue: CGFloat {
        modifiers.compactMap { if case .cornerRadius(let r) = $0 { return r } else { return nil } }.first ?? 0
    }
    var fontWeight: FontWeightType? {
        modifiers.compactMap { if case .font(_, _, let w, _) = $0 { return w } else { return nil } }.first
    }
    var glassStyle: GlassStyleType? {
        modifiers.compactMap { if case .glassEffect(let s) = $0 { return s } else { return nil } }.first
    }
    var shadowRadius: CGFloat {
        modifiers.compactMap { if case .shadow(_, let r, _, _) = $0 { return r } else { return nil } }.first ?? 0
    }
    var blurRadius: CGFloat {
        modifiers.compactMap { if case .blur(let r) = $0 { return r } else { return nil } }.first ?? 0
    }

    mutating func setFrameWidth(_ width: CGFloat?) {
        updateOrAddModifier { mod in
            if case .frame(_, let h, let minW, let maxW, let minH, let maxH, let a) = mod {
                return .frame(width: width, height: h, minWidth: minW, maxWidth: maxW, minHeight: minH, maxHeight: maxH, alignment: a)
            }
            return nil
        } fallback: {
            .frame(width: width, height: nil, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil)
        }
    }

    mutating func setFrameHeight(_ height: CGFloat?) {
        updateOrAddModifier { mod in
            if case .frame(let w, _, let minW, let maxW, let minH, let maxH, let a) = mod {
                return .frame(width: w, height: height, minWidth: minW, maxWidth: maxW, minHeight: minH, maxHeight: maxH, alignment: a)
            }
            return nil
        } fallback: {
            .frame(width: nil, height: height, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil)
        }
    }

    mutating func setPadding(_ amount: CGFloat?) {
        if let amount {
            updateOrAddModifier { mod in
                if case .padding(let edges, _) = mod { return .padding(edges: edges, amount: amount) }
                return nil
            } fallback: { .padding(edges: .all, amount: amount) }
        } else {
            modifiers.removeAll { if case .padding = $0 { return true } else { return false } }
        }
    }

    mutating func setOpacity(_ opacity: Double) {
        if opacity < 1.0 {
            updateOrAddModifier { mod in
                if case .opacity = mod { return .opacity(opacity) }
                return nil
            } fallback: { .opacity(opacity) }
        } else {
            modifiers.removeAll { if case .opacity = $0 { return true } else { return false } }
        }
    }

    mutating func setCornerRadius(_ radius: CGFloat) {
        if radius > 0 {
            updateOrAddModifier { mod in
                if case .cornerRadius = mod { return .cornerRadius(radius) }
                return nil
            } fallback: { .cornerRadius(radius) }
        } else {
            modifiers.removeAll { if case .cornerRadius = $0 { return true } else { return false } }
        }
    }

    mutating func setFontWeight(_ weight: FontWeightType) {
        updateOrAddModifier { mod in
            if case .font(let s, let sz, _, let d) = mod { return .font(style: s, size: sz, weight: weight, design: d) }
            return nil
        } fallback: { .font(style: nil, size: nil, weight: weight, design: nil) }
    }

    mutating func setGlassEffect(_ style: GlassStyleType?) {
        modifiers.removeAll { if case .glassEffect = $0 { return true } else { return false } }
        if let style {
            modifiers.append(.glassEffect(style))
        }
    }

    mutating func setShadowRadius(_ radius: CGFloat) {
        if radius > 0 {
            updateOrAddModifier { mod in
                if case .shadow(let c, _, let x, let y) = mod { return .shadow(color: c, radius: radius, x: x, y: y) }
                return nil
            } fallback: { .shadow(color: .custom(red: 0, green: 0, blue: 0, opacity: 0.2), radius: radius, x: 0, y: 2) }
        } else {
            modifiers.removeAll { if case .shadow = $0 { return true } else { return false } }
        }
    }

    mutating func setBlurRadius(_ radius: CGFloat) {
        if radius > 0 {
            updateOrAddModifier { mod in
                if case .blur = mod { return .blur(radius: radius) }
                return nil
            } fallback: { .blur(radius: radius) }
        } else {
            modifiers.removeAll { if case .blur = $0 { return true } else { return false } }
        }
    }

    // MARK: - Tint Color (single color control)

    /// Gets the effective tint color — checks tint modifier first, then foregroundStyle
    var tintColorValue: DesignColor? {
        // Check for .tint modifier
        if let tint = modifiers.compactMap({ if case .tint(let c) = $0 { return c } else { return nil } }).first {
            return tint
        }
        // Fallback to foregroundStyle
        return modifiers.compactMap { if case .foregroundStyle(let c) = $0 { return c } else { return nil } }.first
    }

    /// Sets tint color — updates both .tint and .foregroundStyle for visual consistency
    mutating func setTintColor(_ color: DesignColor?) {
        // Remove existing tint and foreground
        modifiers.removeAll { mod in
            if case .tint = mod { return true }
            if case .foregroundStyle = mod { return true }
            return false
        }
        if let color {
            modifiers.append(.tint(color))
            modifiers.append(.foregroundStyle(color))
        }
    }

    var shadowColor: DesignColor? {
        modifiers.compactMap { if case .shadow(let c, _, _, _) = $0 { return c } else { return nil } }.first
    }

    mutating func setShadowColor(_ color: DesignColor) {
        updateOrAddModifier { mod in
            if case .shadow(_, let r, let x, let y) = mod { return .shadow(color: color, radius: r, x: x, y: y) }
            return nil
        } fallback: { .shadow(color: color, radius: 4, x: 0, y: 2) }
    }

    // MARK: - Fill Mode (for shapes)

    var fillMode: FillMode {
        for mod in modifiers {
            if case .carPaint = mod { return .carPaint }
        }
        return .solidColor
    }

    mutating func setFillMode(_ mode: FillMode) {
        switch mode {
        case .solidColor:
            modifiers.removeAll { if case .carPaint = $0 { return true } else { return false } }
        case .carPaint:
            if carPaintConfig == nil {
                modifiers.append(.carPaint(.ferrariRed))
            }
        }
    }

    // MARK: - Car Paint

    var carPaintConfig: CarPaintConfig? {
        modifiers.compactMap { if case .carPaint(let c) = $0 { return c } else { return nil } }.first
    }

    mutating func setCarPaint(_ config: CarPaintConfig) {
        modifiers.removeAll { if case .carPaint = $0 { return true } else { return false } }
        modifiers.append(.carPaint(config))
    }

    // MARK: - Offset Properties

    var offsetX: CGFloat? {
        for mod in modifiers {
            if case .offset(let x, _) = mod { return x }
        }
        return nil
    }

    var offsetY: CGFloat? {
        for mod in modifiers {
            if case .offset(_, let y) = mod { return y }
        }
        return nil
    }

    mutating func setOffset(x: CGFloat, y: CGFloat) {
        modifiers.removeAll { if case .offset = $0 { return true } else { return false } }
        if abs(x) > 0.5 || abs(y) > 0.5 {
            modifiers.append(.offset(x: x, y: y))
        }
    }

    // MARK: - Glass Config

    var glassConfig: GlassConfig? {
        modifiers.compactMap { if case .glassConfig(let c) = $0 { return c } else { return nil } }.first
    }

    mutating func setGlassConfig(_ config: GlassConfig) {
        modifiers.removeAll { if case .glassConfig = $0 { return true } else { return false } }
        // Also sync the glassEffect style
        modifiers.removeAll { if case .glassEffect = $0 { return true } else { return false } }
        modifiers.append(.glassEffect(config.style))
        modifiers.append(.glassConfig(config))
    }

    private mutating func updateOrAddModifier(
        update: (DesignModifier) -> DesignModifier?,
        fallback: () -> DesignModifier
    ) {
        for i in modifiers.indices {
            if let updated = update(modifiers[i]) {
                modifiers[i] = updated
                return
            }
        }
        modifiers.append(fallback())
    }
}

// MARK: - Payload Extensions

extension ElementPayload {
    var hasTextProperties: Bool {
        switch self {
        case .text, .button, .label: return true
        default: return false
        }
    }

    var isShape: Bool {
        switch self {
        case .rectangle, .circle, .roundedRectangle, .capsule, .color: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .vStack:           return "VStack"
        case .hStack:           return "HStack"
        case .zStack:           return "ZStack"
        case .lazyVGrid:        return "LazyVGrid"
        case .lazyHGrid:        return "LazyHGrid"
        case .scrollView:       return "ScrollView"
        case .text:             return "Text"
        case .image:            return "Image"
        case .rectangle:        return "Rectangle"
        case .circle:           return "Circle"
        case .roundedRectangle: return "RoundedRectangle"
        case .capsule:          return "Capsule"
        case .spacer:           return "Spacer"
        case .divider:          return "Divider"
        case .color:            return "Color"
        case .navigationStack:  return "NavigationStack"
        case .tabView:          return "TabView"
        case .sheet:            return "Sheet"
        case .button:           return "Button"
        case .textField:        return "TextField"
        case .secureField:      return "SecureField"
        case .toggle:           return "Toggle"
        case .slider:           return "Slider"
        case .picker:           return "Picker"
        case .stepper:          return "Stepper"
        case .datePicker:       return "DatePicker"
        case .progressView:     return "ProgressView"
        case .label:            return "Label"
        case .list:             return "List"
        case .form:             return "Form"
        case .group:            return "Group"
        }
    }

    var icon: String {
        switch self {
        case .vStack:           return "arrow.down.square"
        case .hStack:           return "arrow.right.square"
        case .zStack:           return "square.on.square"
        case .lazyVGrid:        return "square.grid.3x3"
        case .lazyHGrid:        return "square.grid.3x3"
        case .scrollView:       return "scroll"
        case .text:             return "textformat"
        case .image:            return "photo"
        case .rectangle:        return "rectangle"
        case .circle:           return "circle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .capsule:          return "capsule"
        case .spacer:           return "arrow.up.and.down"
        case .divider:          return "minus"
        case .color:            return "paintpalette"
        case .navigationStack:  return "arrow.triangle.branch"
        case .tabView:          return "rectangle.bottomhalf.filled"
        case .sheet:            return "rectangle.bottomthird.inset.filled"
        case .button:           return "button.horizontal.top.press"
        case .textField:        return "character.cursor.ibeam"
        case .secureField:      return "lock.rectangle"
        case .toggle:           return "switch.2"
        case .slider:           return "slider.horizontal.below.rectangle"
        case .picker:           return "list.bullet"
        case .stepper:          return "plus.forwardslash.minus"
        case .datePicker:       return "calendar"
        case .progressView:     return "circle.dotted"
        case .label:            return "tag"
        case .list:             return "list.bullet.rectangle"
        case .form:             return "doc.plaintext"
        case .group:            return "folder"
        }
    }
}
