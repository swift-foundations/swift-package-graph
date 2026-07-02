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
        // v0.2: discover pipeline uses swift-process (subprocess spawn for
        // `swift package dump-package`), swift-file-system (workspace walk),
        // and swift-json (Foundation-free JSON parsing via JSON.Serializable
        // walking — replaces Foundation's JSONDecoder).
        // swift-async / swift-path-primitives / swift-time-primitives skipped
        // for v0.2 — `TaskGroup` covers concurrency, `Swift.String` covers path
        // joining, no timeouts in discover.
        .package(url: "https://github.com/swift-primitives/swift-byte-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-graph-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-process.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-arguments.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Package Graph",
            dependencies: [
                .product(name: "Byte Primitive", package: "swift-byte-primitives"),
                .product(name: "Graph Primitive", package: "swift-graph-primitives"),
                .product(name: "Graph Topological Primitives", package: "swift-graph-primitives"),
                .product(name: "Graph SCC Primitives", package: "swift-graph-primitives"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Paths", package: "swift-paths"),
                .product(name: "JSON", package: "swift-json")
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
