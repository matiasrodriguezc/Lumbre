// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumbreCore",
    defaultLocalization: "es",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LumbreCore", targets: ["LumbreCore"]),
    ],
    targets: [
        .target(name: "LumbreCore"),
        .testTarget(name: "LumbreCoreTests", dependencies: ["LumbreCore"]),
    ]
)
