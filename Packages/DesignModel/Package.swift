// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesignModel",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesignModel", targets: ["DesignModel"]),
    ],
    targets: [
        .target(name: "DesignModel"),
        .testTarget(name: "DesignModelTests", dependencies: ["DesignModel"]),
    ]
)
