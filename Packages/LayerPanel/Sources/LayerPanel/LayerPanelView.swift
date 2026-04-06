import SwiftUI
import DesignModel
import AppKit

/// Layer panel showing the element hierarchy as a tree view.
/// Supports selection, visibility toggles, drag reordering, grouping, and context menus.
public struct LayerPanelView: View {
    @ObservedObject var document: DesignDocument

    public init(document: DesignDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with action buttons
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()

                // Add Group button
                Button {
                    addGroupToSelected()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Add Group (⌘G)")

                // Delete button
                Button {
                    if let id = document.selectedElementID {
                        document.removeElement(id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(document.selectedElementID == nil)
                .help("Delete Selected (⌫)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Layer tree
            if let page = document.selectedPage {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let entries = layerTree(node: page.rootElement, depth: 0, parentID: nil)
                        ForEach(entries) { entry in
                            LayerRow(
                                node: entry.node,
                                depth: entry.depth,
                                parentID: entry.parentID,
                                isSelected: document.selectedElementID == entry.node.id || document.selectedElementIDs.contains(entry.node.id),
                                isExpanded: expandedIDs.contains(entry.node.id),
                                dropTarget: dropTarget,
                                document: document,
                                onSelect: {
                                    if NSEvent.modifierFlags.contains(.shift) {
                                        document.addToSelection(entry.node.id)
                                    } else {
                                        document.selectElement(entry.node.id)
                                    }
                                },
                                onToggleExpand: { toggleExpand(entry.node.id) },
                                onToggleVisibility: {
                                    document.updateElement(entry.node.id) { $0.isVisible.toggle() }
                                },
                                onToggleLock: {
                                    document.updateElement(entry.node.id) { $0.isLocked.toggle() }
                                },
                                onDelete: {
                                    document.removeElement(entry.node.id)
                                },
                                onDuplicate: {
                                    document.duplicateElement(entry.node.id)
                                },
                                onGroup: {
                                    document.groupElement(entry.node.id)
                                },
                                onUngroup: {
                                    document.ungroupElement(entry.node.id)
                                },
                                onMoveUp: {
                                    moveUp(entry.node.id, parentID: entry.parentID)
                                },
                                onMoveDown: {
                                    moveDown(entry.node.id, parentID: entry.parentID)
                                },
                                onSetDropTarget: { target in
                                    dropTarget = target
                                },
                                onDrop: { sourceID, targetID, position in
                                    performDrop(sourceID: sourceID, targetID: targetID, position: position)
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

    // MARK: - State

    @State private var expandedIDs: Set<UUID> = []
    @State private var dropTarget: DropTarget? = nil

    // MARK: - Tree Building

    private func layerTree(node: ElementNode, depth: Int, parentID: UUID?) -> [LayerEntry] {
        var entries: [LayerEntry] = []
        entries.append(LayerEntry(node: node, depth: depth, parentID: parentID))
        // Only show children if expanded (or root)
        if depth == 0 || expandedIDs.contains(node.id) {
            for child in node.children {
                entries.append(contentsOf: layerTree(node: child, depth: depth + 1, parentID: node.id))
            }
        }
        return entries
    }

    // MARK: - Actions

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func addGroupToSelected() {
        if let selectedID = document.selectedElementID {
            document.groupElement(selectedID)
        } else if let page = document.selectedPage {
            // Add an empty group to root
            let group = ElementNode(name: "Group", payload: .group)
            document.addElement(group, parentID: page.rootElement.id)
        }
    }

    private func moveUp(_ elementID: UUID, parentID: UUID?) {
        guard let parentID else { return }
        guard let page = document.selectedPage,
              let parent = page.rootElement.find(by: parentID),
              let index = parent.children.firstIndex(where: { $0.id == elementID }),
              index > 0 else { return }
        document.moveChildInParent(elementID, parentID: parentID, toIndex: index - 1)
    }

    private func moveDown(_ elementID: UUID, parentID: UUID?) {
        guard let parentID else { return }
        guard let page = document.selectedPage,
              let parent = page.rootElement.find(by: parentID),
              let index = parent.children.firstIndex(where: { $0.id == elementID }),
              index < parent.children.count - 1 else { return }
        document.moveChildInParent(elementID, parentID: parentID, toIndex: index + 1)
    }

    private func performDrop(sourceID: UUID, targetID: UUID, position: DropPosition) {
        guard sourceID != targetID else { return }
        guard let page = document.selectedPage else { return }

        // Don't allow dropping a parent into its own child
        if let sourceNode = page.rootElement.find(by: sourceID),
           sourceNode.find(by: targetID) != nil {
            return
        }

        switch position {
        case .into:
            // Drop into target as last child (target must be container)
            if let targetNode = page.rootElement.find(by: targetID), targetNode.isContainer {
                document.moveElement(sourceID, toParent: targetID, atIndex: targetNode.children.count)
                expandedIDs.insert(targetID)
            }
        case .above:
            // Insert above the target
            if let (parentID, index) = page.rootElement.findParentAndIndex(of: targetID) {
                document.moveElement(sourceID, toParent: parentID, atIndex: index)
            }
        case .below:
            // Insert below the target
            if let (parentID, index) = page.rootElement.findParentAndIndex(of: targetID) {
                document.moveElement(sourceID, toParent: parentID, atIndex: index + 1)
            }
        }

        dropTarget = nil
    }
}

// MARK: - Supporting Types

enum DropPosition {
    case above, below, into
}

struct DropTarget: Equatable {
    let targetID: UUID
    let position: DropPosition
}

struct LayerEntry: Identifiable {
    let node: ElementNode
    let depth: Int
    let parentID: UUID?
    var id: UUID { node.id }
}

// MARK: - Layer Row

struct LayerRow: View {
    let node: ElementNode
    let depth: Int
    let parentID: UUID?
    let isSelected: Bool
    let isExpanded: Bool
    let dropTarget: DropTarget?
    @ObservedObject var document: DesignDocument

    let onSelect: () -> Void
    let onToggleExpand: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onGroup: () -> Void
    let onUngroup: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSetDropTarget: (DropTarget?) -> Void
    let onDrop: (UUID, UUID, DropPosition) -> Void

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var isRenaming = false
    @State private var editedName: String = ""

    private var isDropAbove: Bool {
        dropTarget?.targetID == node.id && dropTarget?.position == .above
    }
    private var isDropBelow: Bool {
        dropTarget?.targetID == node.id && dropTarget?.position == .below
    }
    private var isDropInto: Bool {
        dropTarget?.targetID == node.id && dropTarget?.position == .into
    }

    var body: some View {
        VStack(spacing: 0) {
            if isDropAbove { dropIndicator }
            rowContent
            if isDropBelow { dropIndicator }
        }
    }

    private var rowContent: some View {
        rowHStack
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(rowBorderOverlay)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    editedName = node.name
                    isRenaming = true
                }
            )
            .simultaneousGesture(
                TapGesture(count: 1).onEnded {
                    onSelect()
                }
            )
            .onHover { isHovered = $0 }
            .opacity(isDragging ? 0.4 : 1)
            .draggable(node.id.uuidString) { dragPreview }
            .dropDestination(for: String.self, action: handleDrop, isTargeted: handleDropTargeting)
            .contextMenu { layerContextMenu }
            .padding(.horizontal, 4)
    }

    private var rowHStack: some View {
        HStack(spacing: 4) {
            indentation
            expandToggle
            nodeIcon
            nameView
            Spacer()
            childCountBadge
            hoverControls
        }
    }

    @ViewBuilder
    private var indentation: some View {
        ForEach(0..<depth, id: \.self) { _ in
            Color.clear.frame(width: 16)
        }
    }

    @ViewBuilder
    private var expandToggle: some View {
        if node.isContainer {
            Button { onToggleExpand() } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.borderless)
        } else {
            Color.clear.frame(width: 12)
        }
    }

    private var nodeIcon: some View {
        Image(systemName: iconForPayload(node.payload))
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(width: 16)
    }

    @ViewBuilder
    private var nameView: some View {
        if isRenaming {
            TextField("Name", text: $editedName, onCommit: {
                document.updateElement(node.id) { $0.name = editedName }
                isRenaming = false
            })
            .textFieldStyle(.plain)
            .font(.callout)
            .frame(maxWidth: 120)
            .onExitCommand { isRenaming = false }
        } else {
            let style: AnyShapeStyle = isSelected ? AnyShapeStyle(.white) :
                node.isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
            Text(node.name)
                .font(.callout)
                .foregroundStyle(style)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var childCountBadge: some View {
        if node.isContainer && !node.children.isEmpty {
            let fg: Color = isSelected ? .white.opacity(0.6) : .gray
            let bg: Color = isSelected ? .white.opacity(0.15) : .gray.opacity(0.1)
            Text("\(node.children.count)")
                .font(.system(size: 9))
                .foregroundStyle(fg)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Capsule().fill(bg))
        }
    }

    @ViewBuilder
    private var hoverControls: some View {
        if isHovered || isSelected {
            let fg: Color = isSelected ? .white.opacity(0.7) : .gray
            Button { onToggleVisibility() } label: {
                Image(systemName: node.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(fg)

            Button { onToggleLock() } label: {
                Image(systemName: node.isLocked ? "lock" : "lock.open")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(fg)
        }
    }

    private var rowBackground: Color {
        if isDropInto { return Color.accentColor.opacity(0.2) }
        if isSelected { return Color.accentColor }
        if isHovered { return Color.gray.opacity(0.1) }
        return Color.clear
    }

    private var rowBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(isDropInto ? Color.accentColor : .clear, lineWidth: 1.5)
    }

    private var dragPreview: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForPayload(node.payload))
                .font(.system(size: 11))
            Text(node.name)
                .font(.callout)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .onAppear { isDragging = true }
        .onDisappear { isDragging = false }
    }

    private func handleDrop(_ items: [String], _ location: CGPoint) -> Bool {
        guard let sourceIDString = items.first,
              let sourceID = UUID(uuidString: sourceIDString) else { return false }
        let position = dropTarget?.position ?? .below
        onDrop(sourceID, node.id, position)
        return true
    }

    private func handleDropTargeting(_ isTargeted: Bool) {
        if isTargeted {
            if node.isContainer {
                onSetDropTarget(DropTarget(targetID: node.id, position: .into))
            } else {
                onSetDropTarget(DropTarget(targetID: node.id, position: .below))
            }
        } else if dropTarget?.targetID == node.id {
            onSetDropTarget(nil)
        }
    }

    @ViewBuilder
    private var layerContextMenu: some View {
        Button("Move Up") { onMoveUp() }
        Button("Move Down") { onMoveDown() }
        Divider()
        Button("Group") { onGroup() }
        if node.payload.isGroupPayload {
            Button("Ungroup") { onUngroup() }
        }
        Divider()
        Button("Rename") {
            editedName = node.name
            isRenaming = true
        }
        Button("Duplicate") { onDuplicate() }
        Divider()
        Button(node.isVisible ? "Hide" : "Show") { onToggleVisibility() }
        Button(node.isLocked ? "Unlock" : "Lock") { onToggleLock() }
        Divider()
        Button("Delete", role: .destructive) { onDelete() }
    }

    private var dropIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { _ in
                Color.clear.frame(width: 16)
            }
            Color.clear.frame(width: 16) // match expand arrow
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
        }
        .frame(height: 2)
        .padding(.horizontal, 12)
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
        case .vectorPath:       return "scribble.variable"
        case .importedImage:    return "photo.on.rectangle"
        }
    }
}

// MARK: - ElementPayload Extension

extension ElementPayload {
    var isGroupPayload: Bool {
        if case .group = self { return true }
        return false
    }
}
