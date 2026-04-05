// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeExport",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CodeExport", targets: ["CodeExport"]),
    ],
    dependencies: [
        .package(path: "../DesignModel"),
    ],
    targets: [
        .target(name: "CodeExport", dependencies: ["DesignModel"]),
        .testTarget(name: "CodeExportTests", dependencies: ["CodeExport"]),
    ]
)
