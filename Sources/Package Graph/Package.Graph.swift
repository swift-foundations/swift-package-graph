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

internal import Graph_Primitives_Core
internal import Graph_SCC_Primitives
internal import Graph_Topological_Primitives

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
    /// Structural queries (``cycles()``, ``topologicalOrder()``,
    /// ``stronglyConnectedComponents()``, ``dot()``) compose
    /// `swift-graph-primitives`' `Graph.Sequential` algorithms over
    /// a node-payload of ``Package/Manifest``.
    public struct Graph: ~Copyable, Swift.Sendable {
        @usableFromInline
        internal let manifestByName: [Package.Name: Package.Manifest]

        @usableFromInline
        internal let forwardAdjacency: [Package.Name: Swift.Set<Package.Name>]

        @usableFromInline
        internal let reverseAdjacency: [Package.Name: Swift.Set<Package.Name>]

        internal let sequential: Graph_Primitives_Core.Graph.Sequential<NodeIdentity, Package.Manifest>

        internal let nodeByName: [Package.Name: Graph_Primitives_Core.Graph.Node<NodeIdentity>]

        internal let nameByNode: [Graph_Primitives_Core.Graph.Node<NodeIdentity>: Package.Name]

        public init(_ workspace: borrowing Workspace) throws(Self.Error) {
            var manifestByName: [Package.Name: Package.Manifest] = [:]
            var forwardAdjacency: [Package.Name: Swift.Set<Package.Name>] = [:]
            var reverseAdjacency: [Package.Name: Swift.Set<Package.Name>] = [:]
            var nodeByName: [Package.Name: Graph_Primitives_Core.Graph.Node<NodeIdentity>] = [:]
            var nameByNode: [Graph_Primitives_Core.Graph.Node<NodeIdentity>: Package.Name] = [:]
            var builder = Graph_Primitives_Core.Graph.Sequential<NodeIdentity, Package.Manifest>.Builder()

            for manifest in workspace.manifests {
                manifestByName[manifest.name] = manifest
                let node = builder.allocate(manifest)
                nodeByName[manifest.name] = node
                nameByNode[node] = manifest.name

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
            self.sequential = builder.build()
            self.nodeByName = nodeByName
            self.nameByNode = nameByNode
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

// MARK: - Structural queries

extension Package.Graph {
    /// Adjacency extract bridging ``Package/Manifest`` to the
    /// in-workspace ``Graph_Primitives_Core/Graph/Node`` set.
    ///
    /// Built on demand inside each structural query. The closure
    /// captures ``nodeByName`` by value (Swift dictionary value
    /// semantics) and resolves each ``Package/Dependency`` to its
    /// allocated node; cross-workspace dependencies (those whose
    /// target isn't in the workspace) drop out via `compactMap`.
    internal func makeAdjacencyExtract()
        -> Graph_Primitives_Core.Graph.Adjacency.Extract<
            Package.Manifest,
            NodeIdentity,
            [Graph_Primitives_Core.Graph.Node<NodeIdentity>]
        >
    {
        let nodeByName = self.nodeByName
        return .init { manifest in
            manifest.dependencies.compactMap { nodeByName[$0.name] }
        }
    }

    /// Detect dependency cycles in the workspace.
    ///
    /// Returns one ``Cycle`` per non-trivial strongly-connected
    /// component (size ≥ 2) plus one per single-node SCC that
    /// has a self-edge in the dependency graph. Cycle members
    /// are emitted in lexicographic order of ``Package/Name``.
    ///
    /// Complexity: O(V + E) via Tarjan's SCC primitive in
    /// `swift-graph-primitives`.
    public func cycles() -> [Cycle] {
        let groups = sequential.analyze(using: makeAdjacencyExtract()).scc()
        var result: [Cycle] = []
        for group in groups {
            let names = group.compactMap { nameByNode[$0] }.sorted()
            if names.count >= 2 {
                result.append(Cycle(nodes: names))
            } else if names.count == 1, forwardAdjacency[names[0]]?.contains(names[0]) == true {
                result.append(Cycle(nodes: names))
            }
        }
        return result.sorted { $0.nodes.lexicographicallyPrecedes($1.nodes) }
    }

    /// Return packages in topological order (a package precedes
    /// every package that depends on it). For a chain
    /// `swift-root → swift-middle → swift-leaf` (root depends on
    /// middle, middle depends on leaf), the returned order is
    /// `[swift-leaf, swift-middle, swift-root]` — dependencies
    /// first, dependents last. This is the build-order shape:
    /// process upstream packages before the things that consume
    /// them.
    ///
    /// Throws ``Graph/Error`` with kind ``Graph/Error/Kind/cycleDetected``
    /// if the graph contains cycles. Call ``cycles()`` to enumerate
    /// them.
    ///
    /// Complexity: O(V + E) via the iterative DFS-with-coloring
    /// primitive in `swift-graph-primitives`.
    public func topologicalOrder() throws(Self.Error) -> [Package.Name] {
        let traversal = sequential.traverse.topological(using: makeAdjacencyExtract())
        guard !traversal.hasCycles else {
            throw .init(
                kind: .cycleDetected,
                detail: "graph contains dependency cycles; call cycles() to enumerate"
            )
        }
        // Underlying primitive emits "source-before-referenced-nodes" — for
        // adjacency=dependencies that's "dependents-first". Reverse to get
        // the dependencies-first build-order shape the doc-comment promises.
        let names = traversal.compactMap { nameByNode[$0.node] }
        return Swift.Array(names.reversed())
    }

    /// Return strongly-connected components of the dependency
    /// graph. Each component is a set of packages mutually
    /// reachable via dependency edges.
    ///
    /// Components are returned in reverse-topological order
    /// (sinks first) per Tarjan's algorithm; within each
    /// component, members are emitted in lexicographic order
    /// of ``Package/Name``.
    ///
    /// A graph with no cycles produces one single-node component
    /// per package. ``cycles()`` filters to the non-trivial cases.
    ///
    /// Complexity: O(V + E).
    public func stronglyConnectedComponents() -> [[Package.Name]] {
        let groups = sequential.analyze(using: makeAdjacencyExtract()).scc()
        return groups.map { group in
            group.compactMap { nameByNode[$0] }.sorted()
        }
    }

    /// Emit a GraphViz DOT representation of the workspace
    /// dependency graph. Suitable for piping to `dot`,
    /// Graphviz Online, or any DOT consumer.
    ///
    /// Nodes are emitted in ``Package/Name`` lexicographic order;
    /// edges follow nodes, also sorted, so the output is stable
    /// across runs. Only in-workspace nodes appear — dependencies
    /// pointing outside the workspace are omitted.
    public func dot() -> Swift.String {
        let sortedNames = manifestByName.keys.sorted()
        var output = "digraph PackageGraph {\n"
        for name in sortedNames {
            output += "  \"\(name.underlying)\";\n"
        }
        for source in sortedNames {
            guard let targets = forwardAdjacency[source] else { continue }
            for target in targets.sorted() where manifestByName[target] != nil {
                output += "  \"\(source.underlying)\" -> \"\(target.underlying)\";\n"
            }
        }
        output += "}\n"
        return output
    }
}
