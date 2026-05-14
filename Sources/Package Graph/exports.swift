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
// v0.1 does not re-export `Graph_Primitives_Core` — the internal-only
// graph algorithms are an implementation detail. v0.2 will re-export
// once we compose `Graph.Sequential` for topological / cycle / SCC
// queries that consumers may want to drive directly.

@_exported public import SPM_Standard
