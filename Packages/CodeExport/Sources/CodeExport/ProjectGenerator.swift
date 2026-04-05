import Foundation
import DesignModel

/// Generates a complete Xcode-ready project folder from a DesignDocument.
public struct ProjectGenerator {
    let emitter = SwiftUIEmitter()

    public init() {}

    /// Generate all files for a project and return as a dictionary of path → content.
    public func generate(document: DesignDocument) -> [String: String] {
        var files: [String: String] = [:]
        let name = document.exportConfig.projectName

        // App entry point
        files["\(name)/\(name)App.swift"] = generateAppFile(document: document)

        // Views
        for page in document.pages {
            let viewName = sanitizeViewName(page.name)
            files["\(name)/Views/\(viewName).swift"] = emitter.emit(page: page, viewName: viewName)
        }

        // Theme
        files["\(name)/Theme/AppColors.swift"] = generateColorsFile(tokens: document.tokens)
        files["\(name)/Theme/AppSpacing.swift"] = generateSpacingFile(tokens: document.tokens)
        files["\(name)/Theme/AppFonts.swift"] = generateFontsFile()

        return files
    }

    /// Write generated files to a directory
    public func write(document: DesignDocument, to directory: URL) throws {
        let files = generate(document: document)
        let fm = FileManager.default

        for (path, content) in files {
            let fileURL = directory.appendingPathComponent(path)
            let dir = fileURL.deletingLastPathComponent()

            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - File Generators

    private func generateAppFile(document: DesignDocument) -> String {
        let name = document.exportConfig.projectName
        let firstPage = document.pages.first.map { sanitizeViewName($0.name) } ?? "ContentView"

        return """
        import SwiftUI

        @main
        struct \(name)App: App {
            var body: some Scene {
                WindowGroup {
                    \(firstPage)()
                }
            }
        }
        """
    }

    private func generateColorsFile(tokens: DesignTokenSet) -> String {
        return """
        import SwiftUI

        enum AppColors {
            static let accent = Color.accentColor
            static let background = Color(.systemBackground)
            static let text = Color(.label)
        }
        """
    }

    private func generateSpacingFile(tokens: DesignTokenSet) -> String {
        let values = tokens.spacingScale.map { "    static let sp\(Int($0)) = CGFloat(\(Int($0)))" }
        return """
        import SwiftUI

        enum AppSpacing {
        \(values.joined(separator: "\n"))
        }
        """
    }

    private func generateFontsFile() -> String {
        return """
        import SwiftUI

        enum AppFonts {
            static let largeTitle = Font.largeTitle
            static let title = Font.title
            static let title2 = Font.title2
            static let title3 = Font.title3
            static let headline = Font.headline
            static let body = Font.body
            static let callout = Font.callout
            static let subheadline = Font.subheadline
            static let footnote = Font.footnote
            static let caption = Font.caption
            static let caption2 = Font.caption2
        }
        """
    }

    private func sanitizeViewName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let first = cleaned.prefix(1).uppercased()
        let rest = cleaned.dropFirst()
        return first + rest + "View"
    }
}
