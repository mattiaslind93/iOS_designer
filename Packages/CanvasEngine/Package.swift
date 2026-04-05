// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CanvasEngine", targets: ["CanvasEngine"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "CanvasEngine", dependencies: ["DesignModel"]),
        .testTarget(name: "CanvasEngineTests", dependencies: ["CanvasEngine"]),
    ]
)
