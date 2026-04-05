// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOSDesigner",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [
        .package(path: "Packages/DesignModel"),
        .package(path: "Packages/CanvasEngine"),
        .package(path: "Packages/ComponentLibrary"),
        .package(path: "Packages/PropertyInspector"),
        .package(path: "Packages/LayerPanel"),
        .package(path: "Packages/AnimationEditor"),
        .package(path: "Packages/CodeExport"),
    ],
    targets: []
)
