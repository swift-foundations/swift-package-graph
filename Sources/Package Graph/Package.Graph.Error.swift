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
  /// Errors thrown by graph construction and graph queries.
  public struct Error: Swift.Error, Swift.Sendable, Swift.Hashable {
    public let kind: Kind
    public let detail: Swift.String

    public init(kind: Kind, detail: Swift.String = "") {
      self.kind = kind
      self.detail = detail
    }
  }
}
