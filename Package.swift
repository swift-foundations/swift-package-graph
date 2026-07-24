// swift-tools-version: 6.3.3

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-package-graph open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-package-graph project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-package-graph",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "Package Graph", targets: ["Package Graph"]),
        .executable(name: "package-graph", targets: ["Package Graph CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-graph-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-package-manager.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-arguments.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Package Graph",
            dependencies: [
                .product(name: "Graph Primitive", package: "swift-graph-primitives"),
                .product(name: "Graph Topological Primitives", package: "swift-graph-primitives"),
                .product(name: "Graph SCC Primitives", package: "swift-graph-primitives"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "Package Manager", package: "swift-package-manager"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Paths", package: "swift-paths"),
            ],
            path: "Sources/Package Graph"
        ),
        .executableTarget(
            name: "Package Graph CLI",
            dependencies: [
                "Package Graph",
                .product(name: "Command", package: "swift-arguments")
            ],
            path: "Sources/Package Graph CLI"
        ),
        .testTarget(
            name: "Package Graph Tests",
            dependencies: [
                "Package Graph",
                .product(name: "File System", package: "swift-file-system")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
