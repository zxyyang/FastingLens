// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppDomain",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AppDomain",
            targets: ["AppDomain"]
        )
    ],
    targets: [
        .target(
            name: "AppDomain"
        ),
        .testTarget(
            name: "AppDomainTests",
            dependencies: ["AppDomain"]
        )
    ]
)
