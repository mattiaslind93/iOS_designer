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

    // MARK: - Element Operations

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

    /// Duplicate an element (copies it as a sibling right after the original).
    public func duplicateElement(_ elementID: UUID) {
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

    /// Wrap selected element(s) in a new group container.
    public func groupElement(_ elementID: UUID) {
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

    /// Ungroup: move children out and remove the group container.
    public func ungroupElement(_ elementID: UUID) {
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
