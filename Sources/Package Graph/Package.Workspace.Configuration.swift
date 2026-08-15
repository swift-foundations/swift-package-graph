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

// `Path` is the publicly re-exported `Paths.Path` per `exports.swift`.

extension Package.Workspace {
    /// Tunables for ``Package/Workspace/discover(at:configuration:)``.
    public struct Configuration: Swift.Sendable, Swift.Hashable {
        /// Maximum directory-tree depth the discoverer walks
        /// looking for `Package.swift` files. Default 2 matches
        /// the Institute's `~/Developer/<org>/<package>/` layout
        /// (root → org → package).
        public var maxDepth: Swift.Int

        /// Maximum concurrent `swift package dump-package`
        /// subprocesses. Bounds memory + CPU pressure during a
        /// full-workspace cold load. Default 8 is a reasonable
        /// floor for a modern multi-core developer machine;
        /// tune up on high-core-count hosts.
        public var maxConcurrentLoads: Swift.Int

        /// Optional explicit path to the `swift` executable. `nil`
        /// resolves via `$PATH` (the default). Used by callers that
        /// need to pin the toolchain (e.g., a non-default Swift
        /// version, a vendored toolchain for hermetic builds).
        public var swiftExecutable: Paths.Path?

        public init(
            maxDepth: Swift.Int = 2,
            maxConcurrentLoads: Swift.Int = 8,
            swiftExecutable: Paths.Path? = nil
        ) {
            self.maxDepth = maxDepth
            self.maxConcurrentLoads = maxConcurrentLoads
            self.swiftExecutable = swiftExecutable
        }
    }
}
