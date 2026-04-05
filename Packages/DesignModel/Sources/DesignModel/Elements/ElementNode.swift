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

    public init(
        id: UUID = UUID(),
        name: String,
        payload: ElementPayload,
        modifiers: [DesignModifier] = [],
        children: [ElementNode] = [],
        isLocked: Bool = false,
        isVisible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.payload = payload
        self.modifiers = modifiers
        self.children = children
        self.isLocked = isLocked
        self.isVisible = isVisible
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
}
