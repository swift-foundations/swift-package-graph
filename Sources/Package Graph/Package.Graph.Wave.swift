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

extension Package.Graph {
  /// A single wave of transitive dependents — all packages at
  /// breadth-first distance ``depth`` from the source.
  ///
  /// Produced by ``Package/Graph/transitiveDependents(of:depth:)``.
  /// Wave depth `1` is direct dependents; `2` is dependents of
  /// dependents (excluding those already in wave 1); etc.
  /// Diamond-shaped graphs assign each node to the smallest wave
  /// in which it appears.
  public struct Wave: Swift.Sendable, Swift.Hashable {
    /// The breadth-first distance from the source package.
    public let depth: Swift.Int

    /// The set of package names at this wave. Disjoint from
    /// all prior waves' packages by construction.
    public let packages: Swift.Set<Package.Name>

    public init(depth: Swift.Int, packages: Swift.Set<Package.Name>) {
      self.depth = depth
      self.packages = packages
    }
  }
}
