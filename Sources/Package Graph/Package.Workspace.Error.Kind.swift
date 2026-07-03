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

extension Package.Workspace.Error {
  /// Failure categories for ``Package/Workspace/Error``.
  public enum Kind: Swift.Sendable, Swift.Hashable {
    /// The workspace root does not exist on disk.
    case rootDoesNotExist

    /// The walk completed but no `Package.swift` files
    /// were found within `maxDepth` levels of the root.
    case noPackagesFound

    /// `swift package dump-package` failed for one or more
    /// packages within the workspace. `detail` identifies
    /// which.
    case manifestLoadFailed

    /// JSON output from `dump-package` could not be decoded.
    case invalidManifestJSON

    /// Subprocess invocation failed (e.g., `swift` executable
    /// not found, permission denied, signal received).
    case subprocessError

    /// Scaffolded API surface; no production impl yet.
    case notImplemented
  }
}
