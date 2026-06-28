// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HTTPClientLib",
    platforms: [
        .macOS(.v14)
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
