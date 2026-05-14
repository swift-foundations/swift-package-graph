# swift-package-graph

Package-level dependency graph queries for local SwiftPM workspaces.

Given a directory containing one or more SwiftPM packages, `swift-package-graph` discovers them, loads their manifests via `swift package dump-package`, and builds a typed dependency graph. Consumers query the graph for forward dependencies, reverse dependents, transitive closures, topological order, cycles, strongly connected components, or GraphViz visualization.

The library lives at `Package Graph`; the executable `package-graph` provides the queries from the command line.

## Library use

```swift
import Package_Graph

let workspace = try await Package.Workspace.discover(at: workspaceRoot)
let graph = try Package.Graph(workspace)

// What depends on swift-buffer-primitives?
let dependents = graph.directDependents(of: "swift-buffer-primitives")

// What's the full transitive closure?
let transitive = graph.transitiveDependents(of: "swift-buffer-primitives", depth: .max)
```

## CLI use

```sh
# From a workspace root:
package-graph dependents-of swift-buffer-primitives --depth 2
package-graph dependencies-of swift-array-primitives
package-graph topo
package-graph cycles
package-graph dot -o ecosystem.dot
```

## Architecture

L3 Foundation. Depends on:

- L1: `swift-graph-primitives` (Graph.Sequential + traversal algorithms), `swift-path-primitives`, `swift-time-primitives`.
- L2: `swift-spm-standard` (SwiftPM `Package.Manifest` + `Package.Dependency` types).
- L3: `swift-process` (spawn `swift package dump-package`), `swift-file-system` (walk workspace), `swift-json` (decode manifest output), `swift-async` (concurrent loading), `swift-console` (CLI output).

See `Research/design.md` for the full design rationale and the parent research doc `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` for the use case context.

## Related packages

- [swift-impact](https://github.com/swift-foundations/swift-impact) — orchestrates `swift build` against the dependents this graph identifies, for downstream-impact analysis on package changes.
- [swift-dependency-analysis](https://github.com/swift-foundations/swift-dependency-analysis) — archived predecessor; superseded by this package.

## License

Apache 2.0. See `LICENSE.md`.
