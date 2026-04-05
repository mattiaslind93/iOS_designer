import Foundation

/// Represents a single screen/page in the design document.
/// Each page targets a specific device frame and contains a root element tree.
public struct DesignPage: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var deviceFrame: DeviceFrame
    public var rootElement: ElementNode
    public var animationTimeline: AnimationTimeline
    public var isDarkMode: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Screen 1",
        deviceFrame: DeviceFrame = .iPhone16Pro,
        rootElement: ElementNode? = nil,
        animationTimeline: AnimationTimeline = AnimationTimeline(),
        isDarkMode: Bool = false
    ) {
        self.id = id
        self.name = name
        self.deviceFrame = deviceFrame
        self.rootElement = rootElement ?? ElementNode(
            name: "Root",
            payload: .zStack(alignment: .center),
            modifiers: [
                .background(.system(.systemBackground))
            ]
        )
        self.animationTimeline = animationTimeline
        self.isDarkMode = isDarkMode
    }
}
