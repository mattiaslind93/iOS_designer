import SwiftUI
import DesignModel

/// Sidebar component library with searchable, categorized component list.
/// Components can be dragged onto the canvas to add them to the design.
public struct ComponentLibraryView: View {
    @ObservedObject var document: DesignDocument
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = Set(ComponentCategory.allCases.map(\.rawValue))

    public init(document: DesignDocument) {
        self.document = document
    }

    private var filteredCategories: [(ComponentCategory, [ComponentTemplate])] {
        ComponentCategory.allCases.compactMap { category in
            let components = category.components.filter { template in
                searchText.isEmpty || template.name.localizedCaseInsensitiveContains(searchText)
            }
            return components.isEmpty ? nil : (category, components)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Components")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Search
            TextField("Search components...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            // Categories
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredCategories, id: \.0.id) { category, components in
                        categorySection(category: category, components: components)
                    }
                }
            }

            Divider()

            // Page selector
            pageSelector
        }
    }

    @ViewBuilder
    private func categorySection(category: ComponentCategory, components: [ComponentTemplate]) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategories.contains(category.rawValue) },
                set: { isExpanded in
                    if isExpanded {
                        expandedCategories.insert(category.rawValue)
                    } else {
                        expandedCategories.remove(category.rawValue)
                    }
                }
            )
        ) {
            VStack(spacing: 2) {
                ForEach(components) { template in
                    componentRow(template)
                }
            }
            .padding(.leading, 8)
        } label: {
            Label(category.rawValue, systemImage: category.systemImage)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func componentRow(_ template: ComponentTemplate) -> some View {
        HStack(spacing: 8) {
            Image(systemName: template.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(template.name)
                .font(.callout)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click to add to selected page
            let node = template.createNode()
            document.addElement(node)
        }
        .draggable(template.name) // Simplified; will be expanded with Transferable
        .help("Double-click or drag to add \(template.name)")
    }

    private var pageSelector: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Pages")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    document.addPage()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(document.pages) { page in
                HStack {
                    Image(systemName: "iphone")
                        .foregroundStyle(.secondary)
                    Text(page.name)
                        .font(.callout)
                    Spacer()
                    Text(page.deviceFrame.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    document.selectedPageID == page.id
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
                .onTapGesture {
                    document.selectedPageID = page.id
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
}
