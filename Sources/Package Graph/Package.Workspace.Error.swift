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

extension Package.Workspace {
  /// Errors thrown by ``Package/Workspace/discover(at:configuration:)``.
  public struct Error: Swift.Error, Swift.Sendable, Swift.Hashable {
    /// The failure category.
    public let kind: Kind

    /// Human-readable detail; not load-bearing for programmatic
    /// dispatch. Use ``kind`` for branching.
    public let detail: Swift.String

    public init(kind: Kind, detail: Swift.String = "") {
      self.kind = kind
      self.detail = detail
    }
  }
}
