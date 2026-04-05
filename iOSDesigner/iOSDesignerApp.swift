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
            // Add custom menu commands
            CommandGroup(after: .newItem) {
                Button("New Page") {
                    // Handled via notification
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
}
