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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Element")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            switch element.payload {
            case .text(let content, _):
                LabeledContent("Content") {
                    TextField("Text", text: Binding(
                        get: { content },
                        set: { newContent in
                            document.updateElement(element.id) { node in
                                if case .text(_, let style) = node.payload {
                                    node.payload = .text(content: newContent, style: style)
                                }
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .button(let title, _):
                LabeledContent("Title") {
                    TextField("Title", text: Binding(
                        get: { title },
                        set: { newTitle in
                            document.updateElement(element.id) { node in
                                if case .button(_, let style) = node.payload {
                                    node.payload = .button(title: newTitle, style: style)
                                }
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .image(let systemName, _):
                LabeledContent("SF Symbol") {
                    TextField("Symbol name", text: Binding(
                        get: { systemName ?? "" },
                        set: { newName in
                            document.updateElement(element.id) { node in
                                node.payload = .image(systemName: newName.isEmpty ? nil : newName, assetName: nil)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .toggle(let label, let isOn):
                LabeledContent("Label") {
                    TextField("Label", text: Binding(
                        get: { label },
                        set: { newLabel in
                            document.updateElement(element.id) { node in
                                node.payload = .toggle(label: newLabel, isOn: isOn)
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

            // Frame
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

            // Padding
            HStack(spacing: 8) {
                DimensionField(label: "Pad", value: element.paddingAmount) { newValue in
                    document.updateElement(element.id) { node in
                        node.setPadding(newValue)
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

            // Glass Effect
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
                .frame(width: 100)
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
