// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LayerPanel",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LayerPanel", targets: ["LayerPanel"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "LayerPanel", dependencies: ["DesignModel"]),
        .testTarget(name: "LayerPanelTests", dependencies: ["LayerPanel"]),
    ]
)
