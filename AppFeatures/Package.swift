// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppFeatures",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AppFeatures",
            targets: ["AppFeatures"]
        )
    ],
    targets: [
        .target(
            name: "AppFeatures"
        ),
        .testTarget(
            name: "AppFeaturesTests",
            dependencies: ["AppFeatures"]
        )
    ]
)
