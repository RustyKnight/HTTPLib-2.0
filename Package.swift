// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HTTPLib",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTTPLib",
            targets: ["HTTPLib"]
        )
    ],
    targets: [
        .target(
            name: "HTTPLib"
        ),
        .testTarget(
            name: "HTTPLibTests",
            dependencies: ["HTTPLib"]
        )
    ]
)
