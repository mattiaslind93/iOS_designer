// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LayerPanel",
    platforms: [.macOS("26.0")],
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
