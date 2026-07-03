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
  /// A dependency cycle discovered by ``Package/Graph/cycles()``.
  ///
  /// The `nodes` list traces the cycle in dependency-edge order;
  /// the first node is also the cycle's logical "entry point"
  /// (the lexicographically-smallest node on the cycle, by
  /// canonical-form convention).
  public struct Cycle: Swift.Sendable, Swift.Hashable {
    /// Package names participating in the cycle, in dependency
    /// order. `nodes[i] depends on nodes[i+1]`; `nodes.last
    /// depends on nodes.first`. By construction `nodes.count >= 2`.
    public let nodes: [Package.Name]

    public init(nodes: [Package.Name]) {
      self.nodes = nodes
    }
  }
}
