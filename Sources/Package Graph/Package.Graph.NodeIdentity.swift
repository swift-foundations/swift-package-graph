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
    /// Phantom-type discriminator for node identities within a
    /// ``Package/Graph`` instance.
    ///
    /// Carries no state; serves as the
    /// ``Graph_Primitives_Core/Graph/Sequential`` `Tag` parameter so
    /// `Graph.Node` values cannot cross-pollinate between graph instances
    /// at the type level.
    ///
    /// Internal because ``Package/Graph`` returns ``Package/Name`` from
    /// all public queries — node values never escape the public surface.
    internal enum NodeIdentity {}
}
