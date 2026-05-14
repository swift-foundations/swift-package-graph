// swift-tools-version: 6.3.1

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
        // v0.1: minimum deps for the type model + reverse-dep graph queries.
        // Process / file-system / json / async / console / time-primitives /
        // path-primitives added back when Package.Workspace.discover and the
        // load pipeline land in v0.2.
        .package(path: "../../swift-primitives/swift-graph-primitives"),
        .package(path: "../../swift-standards/swift-spm-standard")
    ],
    targets: [
        .target(
            name: "Package Graph",
            dependencies: [
                .product(name: "Graph Primitives Core", package: "swift-graph-primitives"),
                .product(name: "Graph Topological Primitives", package: "swift-graph-primitives"),
                .product(name: "Graph SCC Primitives", package: "swift-graph-primitives"),
                .product(name: "SPM Standard", package: "swift-spm-standard")
            ],
            path: "Sources/Package Graph"
        ),
        .executableTarget(
            name: "Package Graph CLI",
            dependencies: [
                "Package Graph"
            ],
            path: "Sources/Package Graph CLI"
        ),
        .testTarget(
            name: "Package Graph Tests",
            dependencies: [
                "Package Graph"
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
