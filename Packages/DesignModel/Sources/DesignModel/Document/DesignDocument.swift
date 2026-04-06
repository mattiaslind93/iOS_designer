import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The root document model. Conforms to ReferenceFileDocument for document-based app support.
/// Uses JSON serialization for save/load and snapshot-based undo.
public class DesignDocument: ReferenceFileDocument, ObservableObject {

    // MARK: - Published State

    @Published public var pages: [DesignPage]
    @Published public var tokens: DesignTokenSet
    @Published public var exportConfig: ExportConfig
    @Published public var selectedPageID: UUID?
    @Published public var selectedElementID: UUID?

    /// Multi-selection set. When multiple elements are box-selected,
    /// `selectedElementID` is the "primary" (last tapped / first in set).
    @Published public var selectedElementIDs: Set<UUID> = []

    // MARK: - Undo/Redo History

    /// Maximum number of undo snapshots kept
    private let maxUndoSteps = 30

    /// Past states for undo (newest at the end)
    private var undoStack: [DocumentSnapshot] = []
    /// Future states for redo (newest at the end)
    private var redoStack: [DocumentSnapshot] = []
    /// Suppresses snapshot recording during undo/redo restore
    private var isRestoring = false

    // MARK: - Clipboard

    /// Element stored for copy/paste (in-memory, shared across documents)
    public static var clipboard: ElementNode? = nil

    // MARK: - Document Type

    public static var readableContentTypes: [UTType] { [.iosDesign] }

    // MARK: - Init

    public init(
        pages: [DesignPage] = [DesignPage()],
        tokens: DesignTokenSet = DesignTokenSet(),
        exportConfig: ExportConfig = ExportConfig()
    ) {
        self.pages = pages
        self.tokens = tokens
        self.exportConfig = exportConfig
        self.selectedPageID = pages.first?.id
    }

    // MARK: - ReferenceFileDocument

    public required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        let decoded = try decoder.decode(DocumentData.self, from: data)
        self.pages = decoded.pages
        self.tokens = decoded.tokens
        self.exportConfig = decoded.exportConfig
        self.selectedPageID = decoded.pages.first?.id
    }

    public func snapshot(contentType: UTType) throws -> Data {
        let data = DocumentData(pages: pages, tokens: tokens, exportConfig: exportConfig)
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return try encoder.encode(data)
    }

    public func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }

    // MARK: - Convenience

    public var selectedPage: DesignPage? {
        get { pages.first { $0.id == selectedPageID } }
        set {
            if let newValue, let index = pages.firstIndex(where: { $0.id == newValue.id }) {
                pages[index] = newValue
            }
        }
    }

    public func addPage(name: String = "New Screen", device: DeviceFrame = .iPhone16Pro) {
        let page = DesignPage(name: name, deviceFrame: device)
        pages.append(page)
        selectedPageID = page.id
    }

    public func deletePage(_ id: UUID) {
        pages.removeAll { $0.id == id }
        if selectedPageID == id {
            selectedPageID = pages.first?.id
        }
    }

    // MARK: - Undo / Redo

    /// A lightweight snapshot of the document state for undo/redo.
    private struct DocumentSnapshot {
        let pages: [DesignPage]
        let tokens: DesignTokenSet
        let exportConfig: ExportConfig
        let selectedPageID: UUID?
        let selectedElementID: UUID?
        let selectedElementIDs: Set<UUID>
    }

    private func captureSnapshot() -> DocumentSnapshot {
        DocumentSnapshot(
            pages: pages,
            tokens: tokens,
            exportConfig: exportConfig,
            selectedPageID: selectedPageID,
            selectedElementID: selectedElementID,
            selectedElementIDs: selectedElementIDs
        )
    }

    /// Call before any mutation to push the current state onto the undo stack.
    public func pushUndo() {
        guard !isRestoring else { return }
        undoStack.append(captureSnapshot())
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        // Any new edit clears the redo stack
        redoStack.removeAll()
    }

    /// Undo the last change. Returns true if an undo was performed.
    @discardableResult
    public func undo() -> Bool {
        guard let snapshot = undoStack.popLast() else { return false }
        // Save current state for redo
        redoStack.append(captureSnapshot())
        restore(snapshot)
        return true
    }

    /// Redo a previously undone change. Returns true if a redo was performed.
    @discardableResult
    public func redo() -> Bool {
        guard let snapshot = redoStack.popLast() else { return false }
        // Save current state for undo
        undoStack.append(captureSnapshot())
        restore(snapshot)
        return true
    }

    private func restore(_ snapshot: DocumentSnapshot) {
        isRestoring = true
        pages = snapshot.pages
        tokens = snapshot.tokens
        exportConfig = snapshot.exportConfig
        selectedPageID = snapshot.selectedPageID
        selectedElementID = snapshot.selectedElementID
        selectedElementIDs = snapshot.selectedElementIDs
        isRestoring = false
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Clipboard Operations

    /// Copy the selected element to the clipboard.
    public func copySelectedElement() {
        guard let elementID = selectedElementID,
              let pageID = selectedPageID,
              let page = pages.first(where: { $0.id == pageID }),
              let element = page.rootElement.find(by: elementID) else { return }
        Self.clipboard = element
    }

    /// Cut the selected element (copy + remove).
    public func cutSelectedElement() {
        copySelectedElement()
        if let elementID = selectedElementID {
            pushUndo()
            removeElement(elementID)
        }
    }

    /// Paste the clipboard element as a sibling of the selected element, or into root.
    public func pasteElement() {
        guard let original = Self.clipboard else { return }
        pushUndo()
        let copy = original.deepCopy()

        // Offset the pasted element slightly so it's visible
        if let offsetIdx = copy.modifiers.firstIndex(where: { if case .offset = $0 { return true } else { return false } }) {
            if case .offset(let x, let y) = copy.modifiers[offsetIdx] {
                var mutableCopy = copy
                mutableCopy.modifiers[offsetIdx] = .offset(x: x + 16, y: y + 16)
                addElement(mutableCopy)
                selectedElementID = mutableCopy.id
                return
            }
        }
        addElement(copy)
        selectedElementID = copy.id
    }

    /// Delete the currently selected element(s).
    public func deleteSelectedElement() {
        if selectedElementIDs.count > 1 {
            pushUndo()
            for id in selectedElementIDs {
                removeElement(id)
            }
            selectedElementIDs.removeAll()
            selectedElementID = nil
        } else if let elementID = selectedElementID {
            pushUndo()
            removeElement(elementID)
            selectedElementIDs.removeAll()
        }
    }

    /// Select a single element (clears multi-selection).
    public func selectElement(_ id: UUID) {
        selectedElementID = id
        selectedElementIDs = [id]
    }

    /// Add an element to the current selection (Shift+click).
    public func addToSelection(_ id: UUID) {
        selectedElementIDs.insert(id)
        selectedElementID = id  // primary = most recent
    }

    /// Set multi-selection from box select.
    public func setBoxSelection(_ ids: Set<UUID>) {
        selectedElementIDs = ids
        selectedElementID = ids.first
    }

    /// Clear all selection.
    public func clearSelection() {
        selectedElementID = nil
        selectedElementIDs.removeAll()
    }

    // MARK: - Element Operations (with undo support)

    public func addElement(_ element: ElementNode, toPage pageID: UUID? = nil, parentID: UUID? = nil) {
        let targetPageID = pageID ?? selectedPageID
        guard let index = pages.firstIndex(where: { $0.id == targetPageID }) else { return }

        if let parentID {
            _ = pages[index].rootElement.update(by: parentID) { parent in
                parent.children.append(element)
            }
        } else {
            pages[index].rootElement.children.append(element)
        }
    }

    public func removeElement(_ elementID: UUID, fromPage pageID: UUID? = nil) {
        let targetPageID = pageID ?? selectedPageID
        guard let index = pages.firstIndex(where: { $0.id == targetPageID }) else { return }
        pages[index].rootElement.removeChild(by: elementID)
        if selectedElementID == elementID {
            selectedElementID = nil
        }
    }

    public func updateElement(_ elementID: UUID, transform: (inout ElementNode) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        _ = pages[index].rootElement.update(by: elementID, transform: transform)
        // Explicitly notify observers — deep struct mutations inside arrays
        // may not always trigger @Published change detection
        objectWillChange.send()
    }

    /// Move an element to a new parent at a specific index.
    /// Removes from old location, inserts into new parent's children.
    public func moveElement(_ elementID: UUID, toParent parentID: UUID, atIndex index: Int) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        // Remove from old position
        guard let removed = pages[pageIndex].rootElement.removeChild(by: elementID) else { return }
        // Insert at new position
        _ = pages[pageIndex].rootElement.update(by: parentID) { parent in
            parent.insertChild(removed, at: index)
        }
    }

    /// Reorder a child within its current parent.
    public func moveChildInParent(_ elementID: UUID, parentID: UUID, toIndex: Int) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        _ = pages[pageIndex].rootElement.update(by: parentID) { parent in
            guard let fromIndex = parent.children.firstIndex(where: { $0.id == elementID }) else { return }
            let element = parent.children.remove(at: fromIndex)
            let adjustedIndex = min(toIndex, parent.children.count)
            parent.children.insert(element, at: adjustedIndex)
        }
    }

    /// Duplicate an element (copies it as a sibling right after the original). Pushes undo.
    public func duplicateElement(_ elementID: UUID) {
        pushUndo()
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        // Find the parent that contains this element
        guard let (parentID, childIndex) = pages[pageIndex].rootElement.findParentAndIndex(of: elementID) else { return }
        guard let original = pages[pageIndex].rootElement.find(by: elementID) else { return }
        let copy = original.deepCopy()
        _ = pages[pageIndex].rootElement.update(by: parentID) { parent in
            parent.insertChild(copy, at: childIndex + 1)
        }
        selectedElementID = copy.id
    }

    /// Wrap selected element(s) in a new group container. Pushes undo.
    public func groupElement(_ elementID: UUID) {
        pushUndo()
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        guard let (parentID, childIndex) = pages[pageIndex].rootElement.findParentAndIndex(of: elementID) else { return }
        _ = pages[pageIndex].rootElement.update(by: parentID) { parent in
            let element = parent.children.remove(at: childIndex)
            let group = ElementNode(
                name: "Group",
                payload: .group,
                children: [element]
            )
            parent.insertChild(group, at: childIndex)
        }
    }

    /// Ungroup: move children out and remove the group container. Pushes undo.
    public func ungroupElement(_ elementID: UUID) {
        pushUndo()
        guard let pageIndex = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        guard let (parentID, childIndex) = pages[pageIndex].rootElement.findParentAndIndex(of: elementID) else { return }
        guard let groupNode = pages[pageIndex].rootElement.find(by: elementID) else { return }
        let children = groupNode.children
        _ = pages[pageIndex].rootElement.update(by: parentID) { parent in
            parent.children.remove(at: childIndex)
            for (i, child) in children.enumerated() {
                parent.insertChild(child, at: childIndex + i)
            }
        }
        selectedElementID = children.first?.id
    }
}

// MARK: - Serialization Container

private struct DocumentData: Codable {
    let pages: [DesignPage]
    let tokens: DesignTokenSet
    let exportConfig: ExportConfig
}

// MARK: - Export Config

public struct ExportConfig: Codable, Hashable {
    public var projectName: String
    public var bundleIdentifier: String
    public var deploymentTarget: String
    public var organizationName: String

    public init(
        projectName: String = "MyApp",
        bundleIdentifier: String = "com.example.myapp",
        deploymentTarget: String = "18.0",
        organizationName: String = ""
    ) {
        self.projectName = projectName
        self.bundleIdentifier = bundleIdentifier
        self.deploymentTarget = deploymentTarget
        self.organizationName = organizationName
    }
}

// MARK: - Custom UTType

extension UTType {
    public static let iosDesign = UTType(exportedAs: "com.iosdesigner.document")
}
