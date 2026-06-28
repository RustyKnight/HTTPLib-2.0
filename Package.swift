// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HTTPClientLib",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "HTTPClientLib",
            targets: ["HTTPClientLib"]
        )
    ],
    targets: [
        .target(
            name: "HTTPClientLib"
        ),
        .testTarget(
            name: "HTTPClientLibTests",
            dependencies: ["HTTPClientLib"]
        )
    ]
)
