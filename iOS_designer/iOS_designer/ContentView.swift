//
//  ContentView.swift
//  iOS_designer
//
//  Created by Mattias Lind on 2026-04-05.
//

import SwiftUI
import UniformTypeIdentifiers
import DesignModel
import CanvasEngine
import ComponentLibrary
import PropertyInspector
import LayerPanel
import AnimationEditor
import CodeExport

/// Main application view with a three-column layout:
/// Left sidebar: Component Library + Layer Panel
/// Center: Design Canvas + Animation Editor
/// Right: Property Inspector
struct ContentView: View {
    @ObservedObject var document: DesignDocument
    @State private var showExportSheet = false
    @State private var showImportPanel = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var isRunningSimulator = false
    @State private var simulatorError: String?
    @State private var showSimulatorError = false

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // Left sidebar
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            // Center + Right
            HSplitView {
                // Center: Canvas + Animation timeline
                VStack(spacing: 0) {
                    canvasToolbar
                    Divider()
                    CanvasView(document: document)
                    AnimationEditorView(document: document)
                }

                // Right: Inspector
                InspectorView(document: document)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(document: document)
        }
        .alert("Simulator Error", isPresented: $showSimulatorError) {
            Button("OK") {}
        } message: {
            Text(simulatorError ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewPage)) { _ in
            document.addPage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleDarkMode)) { _ in
            if let index = document.pages.firstIndex(where: { $0.id == document.selectedPageID }) {
                document.pages[index].isDarkMode.toggle()
            }
        }
    }

    // MARK: - Simulator

    private func runInSimulator() {
        isRunningSimulator = true
        Task.detached {
            do {
                try await SimulatorRunner.run(document: document)
                await MainActor.run { isRunningSimulator = false }
            } catch {
                await MainActor.run {
                    isRunningSimulator = false
                    simulatorError = error.localizedDescription
                    showSimulatorError = true
                }
            }
        }
    }

    // MARK: - Import

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .svg, .png, .jpeg, .heic, .tiff, .gif, .bmp, .webP
        ]
        panel.prompt = "Import"
        panel.message = "Select images or SVG files to import"

        panel.begin { response in
            if response == .OK {
                document.importFiles(urls: panel.urls)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VSplitView {
            ComponentLibraryView(document: document)
                .frame(minHeight: 300)

            LayerPanelView(document: document)
                .frame(minHeight: 200)
        }
    }

    // MARK: - Canvas Toolbar

    private var canvasToolbar: some View {
        HStack(spacing: 12) {
            if let pageIndex = document.pages.firstIndex(where: { $0.id == document.selectedPageID }) {
                Picker("Device", selection: $document.pages[pageIndex].deviceFrame) {
                    ForEach(DeviceFrame.allCases) { device in
                        Text(device.displayName).tag(device)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            Divider().frame(height: 20)

            if let page = document.selectedPage {
                Text(page.name)
                    .font(.callout.weight(.medium))
            }

            Spacer()

            if let pageIndex = document.pages.firstIndex(where: { $0.id == document.selectedPageID }) {
                Toggle(isOn: $document.pages[pageIndex].isDarkMode) {
                    Image(systemName: document.pages[pageIndex].isDarkMode ? "moon.fill" : "sun.max")
                }
                .toggleStyle(.button)
                .help("Toggle Dark Mode Preview")
            }

            Divider().frame(height: 20)

            // Import button
            Button {
                importFiles()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: .command)
            .help("Import images or SVG files (⌘I)")

            Divider().frame(height: 20)

            // Run in Simulator button
            Button {
                runInSimulator()
            } label: {
                if isRunningSimulator {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                    Text("Building…")
                } else {
                    Label("Run", systemImage: "play.fill")
                }
            }
            .disabled(isRunningSimulator)
            .keyboardShortcut("r", modifiers: .command)
            .help("Build and run in iOS Simulator (⌘R)")

            Button {
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @ObservedObject var document: DesignDocument
    @Environment(\.dismiss) private var dismiss
    @State private var exportPreview: [String: String] = [:]
    @State private var selectedFile: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export SwiftUI Project")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            HSplitView {
                Form {
                    Section("Project Settings") {
                        TextField("Project Name", text: $document.exportConfig.projectName)
                        TextField("Bundle ID", text: $document.exportConfig.bundleIdentifier)
                        TextField("Deployment Target", text: $document.exportConfig.deploymentTarget)
                        TextField("Organization", text: $document.exportConfig.organizationName)
                    }
                }
                .frame(width: 280)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Generated Files")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    HSplitView {
                        List(Array(exportPreview.keys.sorted()), id: \.self, selection: $selectedFile) { file in
                            Label(file, systemImage: "doc.text")
                                .font(.callout)
                        }
                        .frame(width: 200)

                        ScrollView {
                            if let file = selectedFile, let content = exportPreview[file] {
                                Text(content)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            } else {
                                Text("Select a file to preview")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Export to Folder...") {
                    exportToFolder()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 900, height: 600)
        .onAppear {
            let generator = ProjectGenerator()
            exportPreview = generator.generate(document: document)
            selectedFile = exportPreview.keys.sorted().first
        }
    }

    private func exportToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let generator = ProjectGenerator()
                try? generator.write(document: document, to: url)
                dismiss()
            }
        }
    }
}
