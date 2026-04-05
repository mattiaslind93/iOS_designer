// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PropertyInspector",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PropertyInspector", targets: ["PropertyInspector"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "PropertyInspector", dependencies: ["DesignModel"]),
        .testTarget(name: "PropertyInspectorTests", dependencies: ["PropertyInspector"]),
    ]
)
