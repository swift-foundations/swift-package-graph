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

internal import File_System
internal import Process

// JSON decoding is delegated to ``Package/Manifest/_decode(jsonBytes:)`` in
// `Package.Manifest.Decode.swift` — that file isolates the Foundation
// import to avoid the `Process` (Foundation NSTask) / `Process` (swift-process)
// type collision that arises when both modules are visible in the same file.

extension Package {
    /// A discovered SwiftPM workspace — a directory root plus the
    /// set of `Package.Manifest` values loaded from packages found
    /// under it.
    ///
    /// Construct via ``discover(at:configuration:)``, then build a
    /// ``Package/Graph`` from it.
    public struct Workspace: ~Copyable, Swift.Sendable {
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
    /// Walks the directory tree rooted at `root`, bounded by
    /// ``Configuration/maxDepth``, collecting directories that
    /// contain a `Package.swift`. For each found package, spawns
    /// `swift package dump-package` with `workingDirectory:` set to
    /// the package directory and `stdout: .pipe`, decodes the
    /// captured JSON into a ``Package/Manifest``, and aggregates the
    /// result into a ``Workspace``.
    ///
    /// Concurrency is bounded by
    /// ``Configuration/maxConcurrentLoads``: the function spawns at
    /// most that many subprocesses in flight at once.
    ///
    /// - Parameters:
    ///   - root: Workspace root directory on disk.
    ///   - configuration: Tunables (walk depth, concurrency cap,
    ///     `swift` executable override).
    /// - Returns: A loaded ``Workspace``.
    /// - Throws: ``Workspace/Error`` on directory-walk failure,
    ///   subprocess failure, or manifest-JSON decode failure.
    public static func discover(
        at root: Swift.String,
        configuration: Configuration = .init()
    ) async throws(Self.Error) -> Self {
        guard _directoryExists(at: root) else {
            throw .init(kind: .rootDoesNotExist, detail: root)
        }

        let packageDirectories = _findPackageDirectories(
            under: root, maxDepth: configuration.maxDepth
        )

        guard !packageDirectories.isEmpty else {
            throw .init(
                kind: .noPackagesFound,
                detail: "no Package.swift found within depth \(configuration.maxDepth) of \(root)"
            )
        }

        let swiftExecutable = configuration.swiftExecutable ?? _defaultSwiftExecutable()
        let concurrencyBound = Swift.max(1, configuration.maxConcurrentLoads)

        let manifests: [Package.Manifest]
        do {
            manifests = try await _loadManifestsConcurrently(
                packageDirectories: packageDirectories,
                swiftExecutable: swiftExecutable,
                concurrencyBound: concurrencyBound
            )
        } catch let error as Self.Error {
            throw error
        } catch {
            throw .init(
                kind: .subprocessError,
                detail: "unexpected error during concurrent manifest load: \(error)"
            )
        }

        return Package.Workspace(root: root, manifests: manifests)
    }
}

// MARK: - Internal helpers (filesystem walk)

extension Package.Workspace {
    /// Returns true iff `path` exists on disk AND is a directory.
    @usableFromInline
    internal static func _directoryExists(at path: Swift.String) -> Swift.Bool {
        guard let filePath = try? File.Path(path) else { return false }
        // Treat the path as a directory by attempting to open its entries.
        return (try? File.Directory(filePath).entries()) != nil
    }

    /// Returns true iff `path/Package.swift` exists as a file.
    @usableFromInline
    internal static func _hasPackageSwift(in directory: Swift.String) -> Swift.Bool {
        let manifestPath = directory + "/Package.swift"
        guard let filePath = try? File.Path(manifestPath) else { return false }
        // A file-shape entry check via stat.
        return File.System.Stat.isFile(at: filePath)
    }

    /// Walk depth-bounded breadth-first, returning every directory
    /// at depth ≤ `maxDepth` that contains a `Package.swift`.
    ///
    /// The root itself (depth 0) is included if it contains one.
    /// Symbolic links and hidden directories (`.foo`) are skipped.
    @usableFromInline
    internal static func _findPackageDirectories(
        under root: Swift.String, maxDepth: Swift.Int
    ) -> [Swift.String] {
        var found: [Swift.String] = []
        var queue: [(path: Swift.String, depth: Swift.Int)] = [(root, 0)]

        while !queue.isEmpty {
            let (current, depth) = queue.removeFirst()

            if _hasPackageSwift(in: current) {
                found.append(current)
                // Don't descend into a discovered package — nested
                // packages inside a Swift package (e.g., `.build`,
                // test fixtures) are out of scope for v0.2.
                continue
            }

            guard depth < maxDepth else { continue }

            guard let filePath = try? File.Path(current),
                  let entries = try? File.Directory(filePath).entries()
            else { continue }

            for entry in entries {
                guard entry.type == .directory else { continue }
                // Decode the raw filesystem name to a string for
                // path joining + filtering.
                guard let nameString = Swift.String(entry.name) else { continue }
                if nameString.hasPrefix(".") { continue }  // skip hidden + .build
                queue.append((current + "/" + nameString, depth + 1))
            }
        }
        return found
    }
}

// MARK: - Internal helpers (subprocess + JSON)

extension Package.Workspace {
    /// Default `swift` executable resolution — relies on `$PATH`
    /// lookup at spawn time via `/usr/bin/env`. Callers needing a
    /// pinned toolchain set ``Configuration/swiftExecutable``.
    @usableFromInline
    internal static func _defaultSwiftExecutable() -> Swift.String {
        "/usr/bin/env"
    }

    /// Spawn `swift package dump-package` in `packageDirectory`,
    /// capture stdout, decode as `Package.Manifest`.
    @usableFromInline
    internal static func _loadManifest(
        packageDirectory: Swift.String,
        swiftExecutable: Swift.String
    ) throws(Package.Workspace.Error) -> Package.Manifest {
        let configuration = Process.Spawn.Configuration(
            executable: swiftExecutable,
            arguments: swiftExecutable == "/usr/bin/env"
                ? ["swift", "package", "dump-package"]
                : ["package", "dump-package"],
            stdout: .pipe,
            stderr: .pipe,
            workingDirectory: packageDirectory
        )

        let output: Process.Output
        do {
            output = try Process.Spawn.run(configuration)
        } catch {
            throw .init(
                kind: .subprocessError,
                detail: "spawn failed for '\(packageDirectory)': \(error)"
            )
        }

        guard case .exited(let code) = output.status, code == 0 else {
            let stderrSummary = output.stderr.map {
                Swift.String(decoding: $0, as: Unicode.UTF8.self)
            } ?? ""
            throw .init(
                kind: .manifestLoadFailed,
                detail: "'\(packageDirectory)' exited with non-zero status: \(output.status). stderr: \(stderrSummary)"
            )
        }

        guard let stdoutBytes = output.stdout else {
            throw .init(
                kind: .manifestLoadFailed,
                detail: "'\(packageDirectory)' produced no stdout (pipe was not captured)"
            )
        }

        // swiftlint:disable typed_throws_required
        do {
            return try Package.Manifest._decode(jsonBytes: stdoutBytes)
        } catch {
            throw .init(
                kind: .invalidManifestJSON,
                detail: "'\(packageDirectory)' JSON decode failed: \(error)"
            )
        }
        // swiftlint:enable typed_throws_required
    }

    /// Load manifests in parallel with a concurrency bound.
    ///
    /// Splits `packageDirectories` into chunks of `concurrencyBound`
    /// each; runs every chunk in a `TaskGroup`; concatenates the
    /// chunk results to preserve filesystem-walk ordering.
    @usableFromInline
    internal static func _loadManifestsConcurrently(
        packageDirectories: [Swift.String],
        swiftExecutable: Swift.String,
        concurrencyBound: Swift.Int
    ) async throws -> [Package.Manifest] {
        var results: [Package.Manifest] = []
        var index = 0
        while index < packageDirectories.count {
            let upperIndex = Swift.min(index + concurrencyBound, packageDirectories.count)
            let chunk = Swift.Array(packageDirectories[index..<upperIndex])
            let chunkResults = try await _loadChunk(
                chunk, swiftExecutable: swiftExecutable
            )
            results.append(contentsOf: chunkResults)
            index = upperIndex
        }
        return results
    }

    /// Spawn `swift package dump-package` for every directory in
    /// `chunk` concurrently; collect manifests in input order.
    @usableFromInline
    internal static func _loadChunk(
        _ chunk: [Swift.String], swiftExecutable: Swift.String
    ) async throws -> [Package.Manifest] {
        let exec = swiftExecutable
        return try await withThrowingTaskGroup(
            of: (Swift.Int, Package.Manifest).self
        ) { group in
            for (offset, directory) in chunk.enumerated() {
                group.addTask { () throws -> (Swift.Int, Package.Manifest) in
                    let manifest = try _loadManifest(
                        packageDirectory: directory, swiftExecutable: exec
                    )
                    return (offset, manifest)
                }
            }
            var indexed: [(Swift.Int, Package.Manifest)] = []
            for try await pair in group {
                indexed.append(pair)
            }
            indexed.sort { $0.0 < $1.0 }
            return indexed.map { $0.1 }
        }
    }
}
