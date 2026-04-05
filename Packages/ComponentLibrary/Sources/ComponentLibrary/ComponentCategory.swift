import Foundation
import DesignModel

/// Categories for organizing components in the sidebar.
public enum ComponentCategory: String, CaseIterable, Identifiable {
    case liquidGlass = "Liquid Glass"
    case layout = "Layout"
    case navigation = "Navigation"
    case controls = "Controls"
    case content = "Content"
    case shapes = "Shapes"
    case containers = "Containers"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .liquidGlass: return "circle.hexagongrid"
        case .layout:      return "square.grid.2x2"
        case .navigation:  return "sidebar.squares.leading"
        case .controls:    return "slider.horizontal.3"
        case .content:     return "text.alignleft"
        case .shapes:      return "circle.square"
        case .containers:  return "rectangle.on.rectangle"
        }
    }

    public var components: [ComponentTemplate] {
        switch self {
        case .liquidGlass:
            return [
                ComponentTemplate(
                    name: "Glass Circle Button",
                    icon: "circle.fill",
                    payload: .zStack(alignment: .center),
                    defaultModifiers: [
                        .frame(width: 52, height: 52, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: .center),
                        .glassConfig(GlassConfig(style: .regular, isInteractive: true, shape: .circle)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Icon", payload: .image(systemName: "plus", assetName: nil), modifiers: [
                            .frame(width: 22, height: 22, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                        ])
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Pill Button",
                    icon: "capsule.fill",
                    payload: .hStack(spacing: 8, alignment: .center),
                    defaultModifiers: [
                        .padding(edges: .horizontal, amount: 20),
                        .padding(edges: .vertical, amount: 12),
                        .glassConfig(GlassConfig(style: .regular, isInteractive: true, shape: .capsule)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Icon", payload: .image(systemName: "star.fill", assetName: nil), modifiers: [
                            .frame(width: 16, height: 16, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                        ]),
                        ElementNode(name: "Label", payload: .text(content: "Action", style: .callout))
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Text Button",
                    icon: "textformat",
                    payload: .zStack(alignment: .center),
                    defaultModifiers: [
                        .padding(edges: .horizontal, amount: 24),
                        .padding(edges: .vertical, amount: 12),
                        .glassConfig(GlassConfig(style: .regular, isInteractive: true, shape: .capsule)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Label", payload: .text(content: "Button", style: .body))
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Card",
                    icon: "rectangle.fill",
                    payload: .vStack(spacing: 12, alignment: .leading),
                    defaultModifiers: [
                        .padding(edges: .all, amount: 16),
                        .glassConfig(GlassConfig(style: .regular, shape: .roundedRectangle)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Title", payload: .text(content: "Card Title", style: .headline)),
                        ElementNode(name: "Body", payload: .text(content: "Card description text goes here.", style: .body), modifiers: [
                            .foregroundStyle(.system(.secondaryLabel))
                        ])
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Toolbar",
                    icon: "rectangle.bottomhalf.filled",
                    payload: .hStack(spacing: 24, alignment: .center),
                    defaultModifiers: [
                        .padding(edges: .horizontal, amount: 24),
                        .padding(edges: .vertical, amount: 12),
                        .glassConfig(GlassConfig(style: .regular, shape: .capsule)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Item 1", payload: .image(systemName: "house.fill", assetName: nil), modifiers: [
                            .frame(width: 22, height: 22, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                            .foregroundStyle(.system(.label))
                        ]),
                        ElementNode(name: "Item 2", payload: .image(systemName: "magnifyingglass", assetName: nil), modifiers: [
                            .frame(width: 22, height: 22, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                            .foregroundStyle(.system(.secondaryLabel))
                        ]),
                        ElementNode(name: "Item 3", payload: .image(systemName: "person.fill", assetName: nil), modifiers: [
                            .frame(width: 22, height: 22, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                            .foregroundStyle(.system(.secondaryLabel))
                        ])
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Floating Action",
                    icon: "plus.circle.fill",
                    payload: .zStack(alignment: .center),
                    defaultModifiers: [
                        .frame(width: 60, height: 60, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: .center),
                        .glassConfig(GlassConfig(style: .regular, isInteractive: true, shape: .circle)),
                        .shadow(color: .custom(red: 0, green: 0, blue: 0, opacity: 0.15), radius: 8, x: 0, y: 4),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Icon", payload: .image(systemName: "plus", assetName: nil), modifiers: [
                            .frame(width: 24, height: 24, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                            .foregroundStyle(.system(.accentColor)),
                            .font(style: nil, size: nil, weight: .semibold, design: nil)
                        ])
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Search Bar",
                    icon: "magnifyingglass",
                    payload: .hStack(spacing: 8, alignment: .center),
                    defaultModifiers: [
                        .padding(edges: .horizontal, amount: 16),
                        .padding(edges: .vertical, amount: 10),
                        .frame(width: nil, height: nil, minWidth: nil, maxWidth: .infinity, minHeight: nil, maxHeight: nil, alignment: nil),
                        .glassConfig(GlassConfig(style: .regular, shape: .capsule)),
                    ],
                    defaultChildren: [
                        ElementNode(name: "Icon", payload: .image(systemName: "magnifyingglass", assetName: nil), modifiers: [
                            .frame(width: 16, height: 16, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                            .foregroundStyle(.system(.tertiaryLabel))
                        ]),
                        ElementNode(name: "Placeholder", payload: .text(content: "Search", style: .body), modifiers: [
                            .foregroundStyle(.system(.tertiaryLabel))
                        ])
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Nav Bar",
                    icon: "arrow.triangle.branch",
                    payload: .navigationStack(title: "Title", displayMode: .large),
                    defaultModifiers: [
                        .glassConfig(GlassConfig(style: .regular, shape: .rectangle)),
                    ]
                ),
                ComponentTemplate(
                    name: "Glass Tab Bar",
                    icon: "rectangle.bottomhalf.filled",
                    payload: .tabView(tabs: [
                        TabItemConfig(title: "Home", systemImage: "house.fill"),
                        TabItemConfig(title: "Search", systemImage: "magnifyingglass"),
                        TabItemConfig(title: "Favorites", systemImage: "heart.fill"),
                        TabItemConfig(title: "Profile", systemImage: "person.fill"),
                    ]),
                    defaultModifiers: [
                        .glassConfig(GlassConfig(style: .regular, shape: .capsule)),
                    ]
                ),
            ]
        case .layout:
            return [
                ComponentTemplate(name: "VStack", icon: "arrow.down.square", payload: .vStack(spacing: 8, alignment: .center)),
                ComponentTemplate(name: "HStack", icon: "arrow.right.square", payload: .hStack(spacing: 8, alignment: .center)),
                ComponentTemplate(name: "ZStack", icon: "square.on.square", payload: .zStack(alignment: .center)),
                ComponentTemplate(name: "ScrollView", icon: "scroll", payload: .scrollView(axis: .vertical)),
                ComponentTemplate(name: "LazyVGrid", icon: "square.grid.3x3", payload: .lazyVGrid(
                    columns: [GridColumnConfig(type: .flexible), GridColumnConfig(type: .flexible)], spacing: 8)),
                ComponentTemplate(name: "LazyHGrid", icon: "square.grid.3x3", payload: .lazyHGrid(
                    rows: [GridColumnConfig(type: .flexible), GridColumnConfig(type: .flexible)], spacing: 8)),
                ComponentTemplate(name: "Spacer", icon: "arrow.up.and.down", payload: .spacer(minLength: nil)),
                ComponentTemplate(name: "Divider", icon: "minus", payload: .divider),
            ]
        case .navigation:
            return [
                ComponentTemplate(name: "NavigationStack", icon: "arrow.triangle.branch", payload: .navigationStack(title: "Title", displayMode: .large)),
                ComponentTemplate(name: "TabView", icon: "rectangle.bottomhalf.filled", payload: .tabView(tabs: [
                    TabItemConfig(title: "Home", systemImage: "house"),
                    TabItemConfig(title: "Search", systemImage: "magnifyingglass"),
                    TabItemConfig(title: "Profile", systemImage: "person"),
                ])),
                ComponentTemplate(name: "Sheet", icon: "rectangle.bottomthird.inset.filled", payload: .sheet(detents: [.medium, .large])),
            ]
        case .controls:
            return [
                ComponentTemplate(name: "Button", icon: "button.horizontal.top.press", payload: .button(title: "Button", style: .borderedProminent)),
                ComponentTemplate(name: "TextField", icon: "character.cursor.ibeam", payload: .textField(placeholder: "Placeholder")),
                ComponentTemplate(name: "SecureField", icon: "lock.rectangle", payload: .secureField(placeholder: "Password")),
                ComponentTemplate(name: "Toggle", icon: "switch.2", payload: .toggle(label: "Toggle", isOn: true)),
                ComponentTemplate(name: "Slider", icon: "slider.horizontal.below.rectangle", payload: .slider(minValue: 0, maxValue: 100, value: 50)),
                ComponentTemplate(name: "Picker", icon: "list.bullet", payload: .picker(label: "Picker", options: ["Option 1", "Option 2", "Option 3"], selection: 0)),
                ComponentTemplate(name: "Stepper", icon: "plus.forwardslash.minus", payload: .stepper(label: "Stepper", minValue: 0, maxValue: 10, value: 5)),
                ComponentTemplate(name: "DatePicker", icon: "calendar", payload: .datePicker(label: "Date")),
                ComponentTemplate(name: "ProgressView", icon: "circle.dotted", payload: .progressView(style: .linear, value: 0.5)),
            ]
        case .content:
            return [
                ComponentTemplate(name: "Text", icon: "textformat", payload: .text(content: "Hello, World!", style: .body)),
                ComponentTemplate(name: "Label", icon: "tag", payload: .label(title: "Label", systemImage: "star")),
                ComponentTemplate(name: "Image (SF Symbol)", icon: "photo", payload: .image(systemName: "star.fill", assetName: nil)),
                ComponentTemplate(name: "Large Title", icon: "textformat.size.larger", payload: .text(content: "Large Title", style: .largeTitle)),
                ComponentTemplate(name: "Headline", icon: "textformat.size", payload: .text(content: "Headline", style: .headline)),
                ComponentTemplate(name: "Caption", icon: "textformat.size.smaller", payload: .text(content: "Caption text", style: .caption)),
            ]
        case .shapes:
            return [
                ComponentTemplate(name: "Rectangle", icon: "rectangle", payload: .rectangle),
                ComponentTemplate(name: "Rounded Rect", icon: "rectangle.roundedtop", payload: .roundedRectangle(cornerRadius: 12)),
                ComponentTemplate(name: "Circle", icon: "circle", payload: .circle),
                ComponentTemplate(name: "Capsule", icon: "capsule", payload: .capsule),
                ComponentTemplate(name: "Color", icon: "paintpalette", payload: .color(designColor: .system(.accentColor))),
            ]
        case .containers:
            return [
                ComponentTemplate(name: "List", icon: "list.bullet.rectangle", payload: .list(style: .insetGrouped)),
                ComponentTemplate(name: "Form", icon: "doc.plaintext", payload: .form),
                ComponentTemplate(name: "Group", icon: "folder", payload: .group),
            ]
        }
    }
}

/// A template for creating a new element from the component library.
public struct ComponentTemplate: Identifiable {
    public let id = UUID()
    public let name: String
    public let icon: String
    public let payload: ElementPayload
    public let defaultModifiers: [DesignModifier]?
    public let defaultChildren: [ElementNode]?

    public init(
        name: String,
        icon: String,
        payload: ElementPayload,
        defaultModifiers: [DesignModifier]? = nil,
        defaultChildren: [ElementNode]? = nil
    ) {
        self.name = name
        self.icon = icon
        self.payload = payload
        self.defaultModifiers = defaultModifiers
        self.defaultChildren = defaultChildren
    }

    /// Create an ElementNode from this template
    public func createNode() -> ElementNode {
        // Use explicit modifiers if provided
        if let mods = defaultModifiers {
            return ElementNode(
                name: name,
                payload: payload,
                modifiers: mods,
                children: defaultChildren ?? []
            )
        }

        // Otherwise use auto-defaults based on type
        var modifiers: [DesignModifier] = []

        switch payload {
        case .rectangle, .circle, .roundedRectangle, .capsule:
            modifiers = [
                .frame(width: 100, height: 100, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
                .foregroundStyle(.system(.accentColor))
            ]
        case .color:
            modifiers = [
                .frame(width: 100, height: 100, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil)
            ]
        case .image:
            modifiers = [
                .frame(width: 44, height: 44, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil)
            ]
        default:
            break
        }

        return ElementNode(
            name: name,
            payload: payload,
            modifiers: modifiers,
            children: defaultChildren ?? []
        )
    }
}
