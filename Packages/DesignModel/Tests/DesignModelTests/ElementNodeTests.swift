import Testing
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

@Test func testDeviceFrames() {
    for device in DeviceFrame.allCases {
        #expect(device.size.width > 0)
        #expect(device.size.height > 0)
        #expect(device.safeAreaInsets.top > 0)
        #expect(device.safeAreaInsets.bottom > 0)
        #expect(!device.displayName.isEmpty)
    }
}
