import SwiftUI
import DesignModel

/// Layer panel showing the element hierarchy as a tree view.
/// Supports selection, visibility toggles, and reordering.
public struct LayerPanelView: View {
    @ObservedObject var document: DesignDocument

    public init(document: DesignDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Layer tree
            if let page = document.selectedPage {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let entries = layerTree(node: page.rootElement, depth: 0)
                        ForEach(entries) { entry in
                            LayerRow(
                                node: entry.node,
                                depth: entry.depth,
                                isSelected: document.selectedElementID == entry.node.id,
                                onSelect: { document.selectedElementID = entry.node.id },
                                onToggleVisibility: {
                                    document.updateElement(entry.node.id) { $0.isVisible.toggle() }
                                },
                                onToggleLock: {
                                    document.updateElement(entry.node.id) { $0.isLocked.toggle() }
                                },
                                onDelete: {
                                    document.removeElement(entry.node.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack {
                    Spacer()
                    Text("No page selected")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func layerTree(node: ElementNode, depth: Int) -> [LayerEntry] {
        var entries: [LayerEntry] = []
        entries.append(LayerEntry(node: node, depth: depth))
        for child in node.children {
            entries.append(contentsOf: layerTree(node: child, depth: depth + 1))
        }
        return entries
    }
}

struct LayerEntry: Identifiable {
    let node: ElementNode
    let depth: Int
    var id: UUID { node.id }
}

/// A single row in the layer panel tree.
struct LayerRow: View {
    let node: ElementNode
    let depth: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            // Indentation
            ForEach(0..<depth, id: \.self) { _ in
                Color.clear.frame(width: 16)
            }

            // Expand indicator for containers
            if node.isContainer && !node.children.isEmpty {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
            } else {
                Color.clear.frame(width: 12)
            }

            // Icon
            Image(systemName: iconForPayload(node.payload))
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 16)

            // Name
            Text(node.name)
                .font(.callout)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : node.isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .lineLimit(1)

            Spacer()

            // Hover controls
            if isHovered || isSelected {
                Button {
                    onToggleVisibility()
                } label: {
                    Image(systemName: node.isVisible ? "eye" : "eye.slash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)

                Button {
                    onToggleLock()
                } label: {
                    Image(systemName: node.isLocked ? "lock" : "lock.open")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            isSelected
                ? Color.accentColor
                : isHovered ? Color.gray.opacity(0.1) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Duplicate") { /* TODO */ }
            Button("Delete", role: .destructive) { onDelete() }
        }
        .padding(.horizontal, 4)
    }

    private func iconForPayload(_ payload: ElementPayload) -> String {
        switch payload {
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
