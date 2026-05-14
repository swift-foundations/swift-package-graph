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

extension Package {
    /// The package-level dependency graph derived from a
    /// ``Workspace``.
    ///
    /// Forward queries (``directDependencies(of:)``,
    /// ``transitiveDependencies(of:)``) answer "what does X
    /// depend on?". Reverse queries (``directDependents(of:)``,
    /// ``transitiveDependents(of:depth:)``) answer "what depends
    /// on X?" — the substrate for downstream-impact analysis.
    ///
    /// v0.1 uses bespoke adjacency tables. v0.2 will compose
    /// `swift-graph-primitives`' `Graph.Sequential` for richer
    /// algorithms (topological order, cycle detection, SCC).
    public struct Graph: ~Copyable, Swift.Sendable {
        @usableFromInline
        internal let manifestByName: [Package.Name: Package.Manifest]

        @usableFromInline
        internal let forwardAdjacency: [Package.Name: Swift.Set<Package.Name>]

        @usableFromInline
        internal let reverseAdjacency: [Package.Name: Swift.Set<Package.Name>]

        public init(_ workspace: borrowing Workspace) throws(Self.Error) {
            var manifestByName: [Package.Name: Package.Manifest] = [:]
            var forwardAdjacency: [Package.Name: Swift.Set<Package.Name>] = [:]
            var reverseAdjacency: [Package.Name: Swift.Set<Package.Name>] = [:]

            for manifest in workspace.manifests {
                manifestByName[manifest.name] = manifest

                var deps = Swift.Set<Package.Name>()
                for dependency in manifest.dependencies {
                    let depName = dependency.name
                    deps.insert(depName)
                    reverseAdjacency[depName, default: []].insert(manifest.name)
                }
                forwardAdjacency[manifest.name] = deps
            }

            self.manifestByName = manifestByName
            self.forwardAdjacency = forwardAdjacency
            self.reverseAdjacency = reverseAdjacency
        }
    }
}

// MARK: - Forward queries

extension Package.Graph {
    /// Returns the names of packages that `package` directly
    /// depends on. Empty if `package` is not in the workspace
    /// or has no declared dependencies.
    public func directDependencies(of package: Package.Name) -> Swift.Set<Package.Name> {
        forwardAdjacency[package] ?? []
    }

    /// Returns the transitive closure of forward dependencies
    /// from `package` — every package reachable via the
    /// dependency edges, in any depth. Excludes `package` itself.
    public func transitiveDependencies(of package: Package.Name) -> Swift.Set<Package.Name> {
        var visited: Swift.Set<Package.Name> = []
        var frontier: Swift.Set<Package.Name> = directDependencies(of: package)
        while let next = frontier.first {
            frontier.remove(next)
            guard !visited.contains(next) else { continue }
            visited.insert(next)
            for downstream in directDependencies(of: next) where !visited.contains(downstream) {
                frontier.insert(downstream)
            }
        }
        return visited
    }
}

// MARK: - Reverse queries

extension Package.Graph {
    /// Returns the names of packages that directly depend on
    /// `package` — the immediate downstream consumers. The
    /// substrate for `swift-impact`'s direct-wave matrix.
    public func directDependents(of package: Package.Name) -> Swift.Set<Package.Name> {
        reverseAdjacency[package] ?? []
    }

    /// Returns the wave-by-wave transitive dependents of `package`,
    /// up to (and including) wave `depth`. Wave 0 is `package`
    /// itself; wave 1 is direct dependents; wave 2+ extends one
    /// level per increment.
    ///
    /// Pass `.max` for the full transitive closure.
    public func transitiveDependents(of package: Package.Name, depth: Swift.Int = .max) -> [Wave] {
        guard depth >= 1 else { return [] }

        var waves: [Wave] = []
        var visited: Swift.Set<Package.Name> = [package]
        var current: Swift.Set<Package.Name> = directDependents(of: package)

        var d = 1
        while !current.isEmpty, d <= depth {
            // Filter out already-visited (handles diamond shapes).
            let waveNodes = current.subtracting(visited)
            guard !waveNodes.isEmpty else { break }
            waves.append(Wave(depth: d, packages: waveNodes))
            visited.formUnion(waveNodes)

            var next: Swift.Set<Package.Name> = []
            for node in waveNodes {
                for upstream in directDependents(of: node) where !visited.contains(upstream) {
                    next.insert(upstream)
                }
            }
            current = next
            d += 1
        }

        return waves
    }
}

// MARK: - Payload access

extension Package.Graph {
    /// Returns the loaded ``Package/Manifest`` for `package`, or
    /// `nil` if the package isn't in this graph's workspace.
    public func manifest(for package: Package.Name) -> Package.Manifest? {
        manifestByName[package]
    }

    /// All package names known to this graph (one entry per
    /// workspace manifest).
    public var packages: Swift.Set<Package.Name> {
        Swift.Set(manifestByName.keys)
    }
}

// MARK: - Structural queries (v0.2+ implementations pending)

extension Package.Graph {
    /// Detect dependency cycles in the workspace.
    ///
    /// v0.1: stub returning empty. v0.2 will compose
    /// `swift-graph-primitives`' cycle-detection primitive.
    public func cycles() -> [Cycle] {
        []
    }

    /// Return packages in topological order (a package precedes
    /// every package that depends on it).
    ///
    /// Throws ``Graph/Error`` with kind ``Graph/Error/Kind/cycleDetected``
    /// if the graph contains cycles.
    ///
    /// v0.1: stub. v0.2 will compose
    /// `swift-graph-primitives`' topological primitive.
    public func topologicalOrder() throws(Self.Error) -> [Package.Name] {
        []
    }

    /// Emit a GraphViz DOT representation suitable for piping
    /// to `dot`, Graphviz Online, or similar visualizers.
    ///
    /// v0.1: stub. v0.2 will emit the proper DOT format.
    public func dot() -> Swift.String {
        ""
    }
}
