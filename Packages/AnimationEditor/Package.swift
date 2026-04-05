// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnimationEditor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AnimationEditor", targets: ["AnimationEditor"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "AnimationEditor", dependencies: ["DesignModel"]),
        .testTarget(name: "AnimationEditorTests", dependencies: ["AnimationEditor"]),
    ]
)
