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
        let decoded = try JSONDecoder().decode(DocumentData.self, from: data)
        self.pages = decoded.pages
        self.tokens = decoded.tokens
        self.exportConfig = decoded.exportConfig
        self.selectedPageID = decoded.pages.first?.id
    }

    public func snapshot(contentType: UTType) throws -> Data {
        let data = DocumentData(pages: pages, tokens: tokens, exportConfig: exportConfig)
        return try JSONEncoder().encode(data)
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
