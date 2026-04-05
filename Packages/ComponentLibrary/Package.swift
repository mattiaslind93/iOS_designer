// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ComponentLibrary",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "ComponentLibrary", targets: ["ComponentLibrary"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "ComponentLibrary", dependencies: ["DesignModel"]),
        .testTarget(name: "ComponentLibraryTests", dependencies: ["ComponentLibrary"]),
    ]
)
