// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Maintini",
    platforms: [
        .macOS(.v11),
        .iOS(.v15),
        .watchOS(.v7),
    ],
    products: [
        .library(
            name: "Maintini",
            targets: ["Maintini"]
        ),
    ],
    targets: [
        .target(
            name: "Maintini"),
        .testTarget(
            name: "MaintiniTests",
            dependencies: ["Maintini"]
        ),
    ]
)
