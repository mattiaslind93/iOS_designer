import Foundation

/// The core recursive tree node representing a single design element.
/// Each node contains a payload (what kind of element), an ordered modifier stack,
/// and optional children for container elements.
public struct ElementNode: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var payload: ElementPayload
    public var modifiers: [DesignModifier]
    public var children: [ElementNode]
    public var isLocked: Bool
    public var isVisible: Bool
    /// Boolean operation config — when set, this vector path acts as a boolean mask on a target sibling
    public var booleanConfig: BooleanConfig?

    public init(
        id: UUID = UUID(),
        name: String,
        payload: ElementPayload,
        modifiers: [DesignModifier] = [],
        children: [ElementNode] = [],
        isLocked: Bool = false,
        isVisible: Bool = true,
        booleanConfig: BooleanConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.payload = payload
        self.modifiers = modifiers
        self.children = children
        self.isLocked = isLocked
        self.isVisible = isVisible
        self.booleanConfig = booleanConfig
    }

    public var isContainer: Bool {
        switch payload {
        case .vStack, .hStack, .zStack, .lazyVGrid, .lazyHGrid,
             .scrollView, .navigationStack, .tabView, .list, .form, .group,
             .sheet:
            return true
        default:
            return false
        }
    }

    /// Recursively find a node by ID
    public func find(by id: UUID) -> ElementNode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.find(by: id) { return found }
        }
        return nil
    }

    /// Recursively update a node by ID
    public mutating func update(by id: UUID, transform: (inout ElementNode) -> Void) -> Bool {
        if self.id == id {
            transform(&self)
            return true
        }
        for i in children.indices {
            if children[i].update(by: id, transform: transform) { return true }
        }
        return false
    }

    /// Remove a child node by ID (recursively)
    @discardableResult
    public mutating func removeChild(by id: UUID) -> ElementNode? {
        if let index = children.firstIndex(where: { $0.id == id }) {
            return children.remove(at: index)
        }
        for i in children.indices {
            if let removed = children[i].removeChild(by: id) {
                return removed
            }
        }
        return nil
    }

    /// Insert a child at a specific index
    public mutating func insertChild(_ node: ElementNode, at index: Int) {
        let safeIndex = min(index, children.count)
        children.insert(node, at: safeIndex)
    }

    /// Find the parent node ID and child index for a given element ID.
    /// Returns (parentID, childIndex) or nil if not found.
    public func findParentAndIndex(of targetID: UUID) -> (UUID, Int)? {
        for (index, child) in children.enumerated() {
            if child.id == targetID {
                return (self.id, index)
            }
            if let result = child.findParentAndIndex(of: targetID) {
                return result
            }
        }
        return nil
    }

    /// Create a deep copy with new UUIDs for this node and all descendants.
    public func deepCopy() -> ElementNode {
        ElementNode(
            id: UUID(),
            name: name + " Copy",
            payload: payload,
            modifiers: modifiers,
            children: children.map { $0.deepCopy() },
            isLocked: isLocked,
            isVisible: isVisible
        )
    }
}
