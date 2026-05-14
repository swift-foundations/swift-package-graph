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

// Re-export ecosystem modules referenced by Package Graph's public surface
// so consumers can use the graph queries ergonomically:
//
// - `SPM_Standard` — the L2 `Package.Manifest`, `Package.Dependency`,
//   `Package.Requirement`, `Target.Dependency`. Stored as the graph's
//   node payload. Brings transitive re-exports of `Package_Primitives`
//   (for `Package.Name`, `Target.Name`, `Product.Name`) and
//   `Version_Primitives` (for `Version.Tools` etc.).
//
// - `Paths` — exposed because ``Package/Workspace/root`` and
//   ``Package/Workspace/discover(at:configuration:)`` are typed in
//   ``File/Path`` (alias of ``Paths/Path``). Consumers constructing a
//   workspace need the typed path constructor; re-export keeps that
//   ergonomic without forcing them to add a `swift-paths` dep.
//
// `Graph_Primitives_Core` is consumed internally to compose
// `Graph.Sequential` for topological / cycle / SCC queries; the public
// surface translates all results back to ``Package/Name`` so consumers
// never receive raw graph types. Re-exporting it would expand the
// public dependency surface for no consumer-visible payoff — keep it
// internal until a real need surfaces.

@_exported public import SPM_Standard
@_exported public import Paths
