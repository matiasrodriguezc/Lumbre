// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumbreDesign",
    defaultLocalization: "es",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LumbreDesign", targets: ["LumbreDesign"]),
    ],
    targets: [
        .target(
            name: "LumbreDesign",
            resources: [.process("Resources")]
        ),
    ]
)
