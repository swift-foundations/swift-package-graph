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
    /// A discovered SwiftPM workspace — a directory root plus the
    /// set of `Package.Manifest` values loaded from packages found
    /// under it.
    ///
    /// Construct via ``discover(at:configuration:)``, then build a
    /// ``Package/Graph`` from it.
    public struct Workspace: Swift.Sendable, Swift.Hashable {
        /// The on-disk root path the workspace was discovered at.
        public let root: Swift.String

        /// Manifests loaded from packages within the workspace.
        /// Order is insertion-order from the filesystem walk; not
        /// otherwise specified.
        public let manifests: [Package.Manifest]

        public init(root: Swift.String, manifests: [Package.Manifest]) {
            self.root = root
            self.manifests = manifests
        }
    }
}

extension Package.Workspace {
    /// Discover SwiftPM packages under `root` and load each
    /// package's manifest.
    ///
    /// v0.1 implementation: stub. Production implementation will
    /// (a) walk the directory tree to ``Configuration/maxDepth``
    /// finding `Package.swift` files, (b) spawn
    /// `swift package dump-package` per package via `swift-process`
    /// with bounded concurrency, (c) decode each subprocess's
    /// stdout JSON into a ``Package/Manifest`` via `swift-json`.
    public static func discover(
        at root: Swift.String,
        configuration: Configuration = .init()
    ) async throws(Self.Error) -> Self {
        throw .init(
            kind: .notImplemented,
            detail: "Package.Workspace.discover scaffolded for v0.1; production impl pending"
        )
    }
}
