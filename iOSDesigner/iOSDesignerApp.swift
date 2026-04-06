import SwiftUI
import UniformTypeIdentifiers
import DesignModel

@main
struct iOSDesignerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { DesignDocument() }) { configuration in
            ContentView(document: configuration.document)
        }
        .commands {
            // Replace standard Edit menu with undo/redo/clipboard support
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NotificationCenter.default.post(name: .performUndo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("Redo") {
                    NotificationCenter.default.post(name: .performRedo, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    NotificationCenter.default.post(name: .performCut, object: nil)
                }
                .keyboardShortcut("x", modifiers: [.command])

                Button("Copy") {
                    NotificationCenter.default.post(name: .performCopy, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command])

                Button("Paste") {
                    NotificationCenter.default.post(name: .performPaste, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command])

                Divider()

                Button("Duplicate") {
                    NotificationCenter.default.post(name: .performDuplicate, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("Delete") {
                    NotificationCenter.default.post(name: .performDelete, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }

            // Add custom menu commands
            CommandGroup(after: .newItem) {
                Button("New Page") {
                    NotificationCenter.default.post(name: .addNewPage, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Grid") {
                    NotificationCenter.default.post(name: .toggleGrid, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command])

                Button("Toggle Dark Mode Preview") {
                    NotificationCenter.default.post(name: .toggleDarkMode, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let addNewPage = Notification.Name("addNewPage")
    static let toggleGrid = Notification.Name("toggleGrid")
    static let toggleDarkMode = Notification.Name("toggleDarkMode")
    static let performUndo = Notification.Name("performUndo")
    static let performRedo = Notification.Name("performRedo")
    static let performCopy = Notification.Name("performCopy")
    static let performCut = Notification.Name("performCut")
    static let performPaste = Notification.Name("performPaste")
    static let performDuplicate = Notification.Name("performDuplicate")
    static let performDelete = Notification.Name("performDelete")
}
