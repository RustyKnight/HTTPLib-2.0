// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HTTPClientLib",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "HTTPClientLib",
            targets: ["HTTPClientLib"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/RustyKnight/SupportLib-2.0", branch: "main")
    ],
    targets: [
        .target(
            name: "HTTPClientLib",
            dependencies: [
                .product(name: "SupportLib", package: "SupportLib-2.0")
            ]
        ),
        .testTarget(
            name: "HTTPClientLibTests",
            dependencies: [
                "HTTPClientLib",
                .product(name: "SupportLib", package: "SupportLib-2.0")
            ]
        )
    ]
)
