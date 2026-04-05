// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesignModel",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "DesignModel", targets: ["DesignModel"]),
    ],
    targets: [
        .target(name: "DesignModel"),
        .testTarget(name: "DesignModelTests", dependencies: ["DesignModel"]),
    ]
)
