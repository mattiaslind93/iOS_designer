import Testing
import Foundation
@testable import DesignModel

@Test func testElementNodeCreation() {
    let node = ElementNode(
        name: "Test",
        payload: .text(content: "Hello", style: .body)
    )
    #expect(node.name == "Test")
    #expect(node.children.isEmpty)
    #expect(node.isVisible)
    #expect(!node.isLocked)
}

@Test func testElementNodeFind() {
    let child = ElementNode(name: "Child", payload: .text(content: "Child", style: nil))
    let parent = ElementNode(
        name: "Parent",
        payload: .vStack(spacing: 8, alignment: .center),
        children: [child]
    )

    let found = parent.find(by: child.id)
    #expect(found?.name == "Child")
}

@Test func testElementNodeUpdate() {
    let child = ElementNode(name: "Child", payload: .text(content: "Old", style: nil))
    var parent = ElementNode(
        name: "Parent",
        payload: .vStack(spacing: 8, alignment: .center),
        children: [child]
    )

    let updated = parent.update(by: child.id) { node in
        node.payload = .text(content: "New", style: .headline)
    }

    #expect(updated)
    if case .text(let content, _) = parent.children[0].payload {
        #expect(content == "New")
    }
}

@Test func testElementNodeRemoveChild() {
    let child = ElementNode(name: "Child", payload: .rectangle)
    var parent = ElementNode(
        name: "Parent",
        payload: .vStack(spacing: nil, alignment: .center),
        children: [child]
    )

    let removed = parent.removeChild(by: child.id)
    #expect(removed != nil)
    #expect(parent.children.isEmpty)
}

@Test func testElementNodeEncodeDecode() throws {
    let node = ElementNode(
        name: "GlassButton",
        payload: .button(title: "Tap", style: .glass),
        modifiers: [
            .glassConfig(GlassConfig(style: .regular, tintColor: .system(.blue), tintIntensity: 0.5, isInteractive: true, shape: .capsule)),
            .carPaint(.ferrariRed),
            .frame(width: 100, height: 100, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
            .opacity(0.8),
            .shadow(color: .custom(red: 0, green: 0, blue: 0, opacity: 0.2), radius: 8, x: 0, y: 4),
        ],
        children: [
            ElementNode(name: "Icon", payload: .image(systemName: "plus", assetName: nil))
        ]
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(node)
    #expect(data.count > 0)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ElementNode.self, from: data)
    #expect(decoded.name == "GlassButton")
    #expect(decoded.modifiers.count == 5)
    #expect(decoded.children.count == 1)
}

@Test func testDesignPageEncodeDecode() throws {
    var page = DesignPage(name: "Test Screen")
    let child = ElementNode(name: "Card", payload: .vStack(spacing: 12, alignment: .leading), modifiers: [
        .glassConfig(GlassConfig(style: .clear, shape: .roundedRectangle)),
        .padding(edges: .all, amount: 16),
        .frame(width: nil, height: nil, minWidth: nil, maxWidth: .infinity, minHeight: nil, maxHeight: nil, alignment: nil),
    ])
    page.rootElement.children.append(child)

    let encoder = JSONEncoder()
    encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
    let data = try encoder.encode(page)

    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
    let decoded = try decoder.decode(DesignPage.self, from: data)
    #expect(decoded.name == "Test Screen")
    #expect(decoded.rootElement.children.count == 1)
}

@Test func testDeviceFrames() {
    for device in DeviceFrame.allCases {
        #expect(device.size.width > 0)
        #expect(device.size.height > 0)
        #expect(device.safeAreaInsets.top > 0)
        #expect(device.safeAreaInsets.bottom > 0)
        #expect(!device.displayName.isEmpty)
    }
}
