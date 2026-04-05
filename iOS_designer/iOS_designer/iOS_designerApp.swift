//
//  iOS_designerApp.swift
//  iOS_designer
//
//  Created by Mattias Lind on 2026-04-05.
//

import SwiftUI
import UniformTypeIdentifiers
import DesignModel

@main
struct iOS_designerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { DesignDocument() }) { configuration in
            ContentView(document: configuration.document)
        }
        .commands {
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
}
