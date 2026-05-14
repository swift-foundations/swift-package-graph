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

import Testing

@testable import Package_Graph

@Suite("Package.Graph")
struct PackageGraphTests {
    @Test("Empty workspace produces empty graph")
    func emptyWorkspace() throws {
        let workspace = Package.Workspace(root: "/tmp", manifests: [])
        let graph = try Package.Graph(workspace)
        #expect(graph.packages.isEmpty)
        #expect(graph.directDependents(of: "anything").isEmpty)
        #expect(graph.directDependencies(of: "anything").isEmpty)
    }

    @Test("Single package, no deps")
    func singlePackageNoDeps() throws {
        let manifest = Package.Manifest(
            name: "swift-leaf",
            toolsVersion: "6.3",
            dependencies: []
        )
        let workspace = Package.Workspace(root: "/tmp", manifests: [manifest])
        let graph = try Package.Graph(workspace)

        #expect(graph.packages == ["swift-leaf"])
        #expect(graph.directDependents(of: "swift-leaf").isEmpty)
        #expect(graph.directDependencies(of: "swift-leaf").isEmpty)
        #expect(graph.manifest(for: "swift-leaf") != nil)
    }

    @Test("Linear chain A→B→C: reverse-dep queries")
    func linearChainReverseDeps() throws {
        let a = Package.Manifest(
            name: "swift-a",
            toolsVersion: "6.3",
            dependencies: [
                Package.Dependency(
                    source: .path("../swift-b"),
                    name: "swift-b",
                    products: ["B"]
                )
            ]
        )
        let b = Package.Manifest(
            name: "swift-b",
            toolsVersion: "6.3",
            dependencies: [
                Package.Dependency(
                    source: .path("../swift-c"),
                    name: "swift-c",
                    products: ["C"]
                )
            ]
        )
        let c = Package.Manifest(name: "swift-c", toolsVersion: "6.3")

        let workspace = Package.Workspace(root: "/tmp", manifests: [a, b, c])
        let graph = try Package.Graph(workspace)

        // Direct dependents.
        #expect(graph.directDependents(of: "swift-c") == ["swift-b"])
        #expect(graph.directDependents(of: "swift-b") == ["swift-a"])
        #expect(graph.directDependents(of: "swift-a").isEmpty)

        // Transitive dependents of swift-c — should yield two waves.
        let waves = graph.transitiveDependents(of: "swift-c", depth: .max)
        #expect(waves.count == 2)
        #expect(waves[0].depth == 1)
        #expect(waves[0].packages == ["swift-b"])
        #expect(waves[1].depth == 2)
        #expect(waves[1].packages == ["swift-a"])
    }

    @Test("Diamond A→B, A→C, B→D, C→D: D's dependents collapse to wave 2")
    func diamondTransitiveDependents() throws {
        let a = Package.Manifest(
            name: "swift-a",
            toolsVersion: "6.3",
            dependencies: [
                .init(source: .path("../swift-b"), name: "swift-b", products: ["B"]),
                .init(source: .path("../swift-c"), name: "swift-c", products: ["C"])
            ]
        )
        let b = Package.Manifest(
            name: "swift-b",
            toolsVersion: "6.3",
            dependencies: [
                .init(source: .path("../swift-d"), name: "swift-d", products: ["D"])
            ]
        )
        let c = Package.Manifest(
            name: "swift-c",
            toolsVersion: "6.3",
            dependencies: [
                .init(source: .path("../swift-d"), name: "swift-d", products: ["D"])
            ]
        )
        let d = Package.Manifest(name: "swift-d", toolsVersion: "6.3")

        let workspace = Package.Workspace(root: "/tmp", manifests: [a, b, c, d])
        let graph = try Package.Graph(workspace)

        // D has 2 direct dependents (B, C).
        #expect(graph.directDependents(of: "swift-d") == ["swift-b", "swift-c"])

        // Transitive waves: wave 1 = {B, C}, wave 2 = {A} (A is in only one wave).
        let waves = graph.transitiveDependents(of: "swift-d", depth: .max)
        #expect(waves.count == 2)
        #expect(waves[0].packages == ["swift-b", "swift-c"])
        #expect(waves[1].packages == ["swift-a"])
    }

    @Test("Depth limit truncates wave list")
    func depthLimitTruncatesWaves() throws {
        // A→B→C→D
        let manifests: [Package.Manifest] = [
            .init(name: "a", toolsVersion: "6.3", dependencies: [.init(source: .path("../b"), name: "b", products: ["B"])]),
            .init(name: "b", toolsVersion: "6.3", dependencies: [.init(source: .path("../c"), name: "c", products: ["C"])]),
            .init(name: "c", toolsVersion: "6.3", dependencies: [.init(source: .path("../d"), name: "d", products: ["D"])]),
            .init(name: "d", toolsVersion: "6.3")
        ]
        let workspace = Package.Workspace(root: "/tmp", manifests: manifests)
        let graph = try Package.Graph(workspace)

        let waves1 = graph.transitiveDependents(of: "d", depth: 1)
        #expect(waves1.count == 1)
        #expect(waves1[0].packages == ["c"])

        let waves2 = graph.transitiveDependents(of: "d", depth: 2)
        #expect(waves2.count == 2)

        let wavesAll = graph.transitiveDependents(of: "d", depth: .max)
        #expect(wavesAll.count == 3)
    }
}
