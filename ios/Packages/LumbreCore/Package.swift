// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumbreCore",
    defaultLocalization: "es",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LumbreCore", targets: ["LumbreCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "LumbreCore",
            dependencies: [.product(name: "Supabase", package: "supabase-swift")]
        ),
        .testTarget(name: "LumbreCoreTests", dependencies: ["LumbreCore"]),
    ]
)
