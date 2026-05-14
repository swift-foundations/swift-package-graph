// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-package-graph open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-package-graph project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// File-scoped to isolate the Foundation import from
// ``Package.Workspace.swift`` — Foundation's `Process` (NSTask) collides
// with swift-process's `Process` enum when both are visible in the same
// file. Keeping the JSON decode here lets the discover pipeline use
// swift-process unambiguously.
//
// `Codable`'s requirements force untyped throws at this call site; the
// caller wraps any `Swift.Error` into ``Package/Workspace/Error`` per
// [API-ERR-001].

// swiftlint:disable no_foundation_import_warning typed_throws_required
import Foundation
// swiftlint:enable no_foundation_import_warning typed_throws_required

extension Package.Manifest {
    /// Decode a UTF-8 byte buffer (typically captured stdout from
    /// `swift package dump-package`) into a `Package.Manifest` via
    /// Foundation's `JSONDecoder` consuming the `Codable` conformance
    /// landed in swift-spm-standard Phase 3a.
    ///
    /// - Parameter bytes: UTF-8-encoded JSON.
    /// - Returns: The decoded manifest.
    /// - Throws: `Swift.Error` from Foundation's decoder.
    @usableFromInline
    internal static func _decode(jsonBytes bytes: [UInt8]) throws -> Package.Manifest {
        let data = Data(bytes)
        return try JSONDecoder().decode(Package.Manifest.self, from: data)
    }
}
