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

// Foundation is used to construct on-disk fixture workspaces (FileManager,
// temp dir, write Package.swift contents) — the discover pipeline under
// test consumes real Swift packages, so the fixtures must be parseable by
// SwiftPM. swiftlint exemption per the existing test pattern.
// swiftlint:disable no_foundation_import_warning typed_throws_required
import Foundation
import Testing

@testable import Package_Graph

@Suite("Package.Workspace.discover")
struct PackageWorkspaceDiscoverTests {
    // MARK: minimal/ — one Package.swift, zero deps

    @Test("minimal workspace yields one manifest")
    func minimalWorkspace() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        try writePackage(
            atDirectory: root + "/swift-leaf",
            name: "swift-leaf",
            dependencies: []
        )

        let workspace = try await Package.Workspace.discover(at: root)
        #expect(workspace.manifests.count == 1)
        #expect(workspace.manifests[0].name == "swift-leaf")
        #expect(workspace.manifests[0].dependencies.isEmpty)
    }

    // MARK: chain/ — A → B → C linear

    @Test("chain workspace yields three manifests with correct adjacency")
    func chainWorkspace() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        try writePackage(
            atDirectory: root + "/swift-c",
            name: "swift-c",
            dependencies: []
        )
        try writePackage(
            atDirectory: root + "/swift-b",
            name: "swift-b",
            dependencies: [(localName: "swift-c", relativePath: "../swift-c")]
        )
        try writePackage(
            atDirectory: root + "/swift-a",
            name: "swift-a",
            dependencies: [(localName: "swift-b", relativePath: "../swift-b")]
        )

        let workspace = try await Package.Workspace.discover(at: root)
        #expect(workspace.manifests.count == 3)

        let names = Set(workspace.manifests.map(\.name))
        #expect(names == ["swift-a", "swift-b", "swift-c"])

        let graph = try Package.Graph(workspace)
        #expect(graph.directDependents(of: "swift-c") == ["swift-b"])
        #expect(graph.directDependents(of: "swift-b") == ["swift-a"])
        #expect(graph.directDependents(of: "swift-a").isEmpty)
    }

    // MARK: diamond/ — A → {B, C} → D, no cycles

    @Test("diamond workspace yields four manifests with no cycles")
    func diamondWorkspace() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        try writePackage(
            atDirectory: root + "/swift-d",
            name: "swift-d",
            dependencies: []
        )
        try writePackage(
            atDirectory: root + "/swift-b",
            name: "swift-b",
            dependencies: [(localName: "swift-d", relativePath: "../swift-d")]
        )
        try writePackage(
            atDirectory: root + "/swift-c",
            name: "swift-c",
            dependencies: [(localName: "swift-d", relativePath: "../swift-d")]
        )
        try writePackage(
            atDirectory: root + "/swift-a",
            name: "swift-a",
            dependencies: [
                (localName: "swift-b", relativePath: "../swift-b"),
                (localName: "swift-c", relativePath: "../swift-c")
            ]
        )

        let workspace = try await Package.Workspace.discover(at: root)
        #expect(workspace.manifests.count == 4)

        let graph = try Package.Graph(workspace)
        #expect(Set(graph.directDependents(of: "swift-d")) == ["swift-b", "swift-c"])
        #expect(graph.cycles().isEmpty)

        // swift-a transitively depends on swift-d through both arms.
        let dependents = graph.transitiveDependents(of: "swift-d", depth: .max)
        let allDependents = Set(dependents.flatMap(\.packages))
        #expect(allDependents == ["swift-a", "swift-b", "swift-c"])
    }

    // MARK: Failure modes

    @Test("nonexistent root throws .rootDoesNotExist")
    func nonexistentRoot() async {
        await #expect(throws: Package.Workspace.Error.self) {
            try await Package.Workspace.discover(
                at: "/nonexistent/path/does/not/exist/\(UUID().uuidString)"
            )
        }
    }

    @Test("empty workspace (no Package.swift) throws .noPackagesFound")
    func emptyWorkspaceThrows() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: root) }

        await #expect(throws: Package.Workspace.Error.self) {
            try await Package.Workspace.discover(at: root)
        }
    }
}

// MARK: - Helpers

private func makeTempDirectory() throws -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("package-graph-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true
    )
    return url.path
}

private func writePackage(
    atDirectory directory: String,
    name: String,
    dependencies: [(localName: String, relativePath: String)]
) throws {
    try FileManager.default.createDirectory(
        atPath: directory, withIntermediateDirectories: true
    )

    // Sources/<name>/<name>.swift placeholder — needed for SwiftPM to
    // accept the package layout under `swift package dump-package`.
    let sourcesDir = directory + "/Sources/" + name
    try FileManager.default.createDirectory(
        atPath: sourcesDir, withIntermediateDirectories: true
    )
    let sourcePlaceholder = "// auto-generated test fixture\n"
    try sourcePlaceholder.write(
        toFile: sourcesDir + "/Placeholder.swift",
        atomically: true, encoding: .utf8
    )

    let depEntries = dependencies.map { dep in
        ".package(path: \"\(dep.relativePath)\")"
    }.joined(separator: ",\n        ")

    let depTargets = dependencies.map { dep in
        ".product(name: \"\(dep.localName)\", package: \"\(dep.localName)\")"
    }.joined(separator: ",\n                ")

    let depsBlock = depEntries.isEmpty ? "" : "    dependencies: [\n        \(depEntries)\n    ],\n"
    let depTargetsBlock = depTargets.isEmpty ? "" : "            dependencies: [\n                \(depTargets)\n            ],\n"

    let manifest = """
    // swift-tools-version: 6.3.1
    import PackageDescription

    let package = Package(
        name: "\(name)",
    \(depsBlock)    targets: [
            .target(
                name: "\(name)",
    \(depTargetsBlock)            path: "Sources/\(name)"
            )
        ]
    )
    """
    try manifest.write(
        toFile: directory + "/Package.swift",
        atomically: true, encoding: .utf8
    )
}
// swiftlint:enable no_foundation_import_warning typed_throws_required
