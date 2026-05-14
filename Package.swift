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
        // v0.2: discover pipeline restores swift-process (subprocess spawn for
        // `swift package dump-package`) and swift-file-system (workspace walk).
        // JSON decoding goes through Foundation's `JSONDecoder` consuming the
        // `Codable` conformance landed in swift-spm-standard Phase 3a — the
        // ecosystem's swift-json deliberately does not bridge Codable, so the
        // pragmatic fit is Foundation here at L3.
        // swift-async / swift-path-primitives / swift-time-primitives skipped
        // for v0.2 — `TaskGroup` covers concurrency, `Swift.String` covers path
        // joining, no timeouts in discover.
        .package(path: "../../swift-primitives/swift-graph-primitives"),
        .package(path: "../../swift-standards/swift-spm-standard"),
        .package(path: "../swift-process"),
        .package(path: "../swift-file-system"),
        .package(path: "../swift-paths")
    ],
    targets: [
        .target(
            name: "Package Graph",
            dependencies: [
                .product(name: "Graph Primitives Core", package: "swift-graph-primitives"),
                .product(name: "Graph Topological Primitives", package: "swift-graph-primitives"),
                .product(name: "Graph SCC Primitives", package: "swift-graph-primitives"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "Process", package: "swift-process"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "Paths", package: "swift-paths")
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
