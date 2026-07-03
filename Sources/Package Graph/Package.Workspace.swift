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

internal import Byte_Primitive
internal import File_System
internal import Process

// JSON decoding is delegated to ``Package/Manifest/decode(jsonBytes:)`` in
// `Package.Manifest.Decode.swift` — that file walks swift-json's typed
// `JSON` DOM directly (Foundation-free; no `JSONDecoder`).

extension Package {
  /// A discovered SwiftPM workspace — a directory root plus the
  /// set of `Package.Manifest` values loaded from packages found
  /// under it.
  ///
  /// Construct via ``discover(at:configuration:)``, then build a
  /// ``Package/Graph`` from it.
  public struct Workspace: ~Copyable, Swift.Sendable {
    /// The on-disk root path the workspace was discovered at.
    public let root: Paths.Path

    /// Manifests loaded from packages within the workspace.
    /// Order is insertion-order from the filesystem walk; not
    /// otherwise specified.
    public let manifests: [Package.Manifest]

    public init(root: Paths.Path, manifests: [Package.Manifest]) {
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
    at root: Paths.Path,
    configuration: Configuration = .init()
  ) async throws(Self.Error) -> Self {
    guard directoryExists(at: root) else {
      throw .init(kind: .rootDoesNotExist, detail: root.string)
    }

    let packageDirectories = findPackageDirectories(
      under: root, maxDepth: configuration.maxDepth
    )

    guard !packageDirectories.isEmpty else {
      throw .init(
        kind: .noPackagesFound,
        detail: "no Package.swift found within depth \(configuration.maxDepth) of \(root.string)"
      )
    }

    let swiftExecutable = configuration.swiftExecutable ?? defaultSwiftExecutable()
    let concurrencyBound = Swift.max(1, configuration.maxConcurrentLoads)

    let manifests = try await loadManifests(
      packageDirectories: packageDirectories,
      swiftExecutable: swiftExecutable,
      concurrencyBound: concurrencyBound
    )

    return Package.Workspace(root: root, manifests: manifests)
  }
}

// MARK: - Filesystem walk (private)

extension Package.Workspace {
  /// True iff `path` is a directory openable for entry listing.
  private static func directoryExists(at path: Paths.Path) -> Swift.Bool {
    do throws(File.Directory.Contents.Error) {
      _ = try File.Directory(path).entries()
      return true
    } catch {
      return false
    }
  }

  /// True iff `directory/Package.swift` exists as a regular file.
  private static func hasManifest(in directory: Paths.Path) -> Swift.Bool {
    File.System.Stat.isFile(at: directory / "Package.swift")
  }

  /// Walk depth-bounded breadth-first, returning every directory
  /// at depth ≤ `maxDepth` that contains a `Package.swift`.
  ///
  /// The root itself (depth 0) is included if it contains one.
  /// Hidden directories (`.foo`) are skipped to avoid descending
  /// into `.build` and similar SwiftPM artefact directories.
  /// Discovered packages are not descended into.
  private static func findPackageDirectories(
    under root: Paths.Path, maxDepth: Swift.Int
  ) -> [Paths.Path] {
    var found: [Paths.Path] = []
    var queue: [(path: Paths.Path, depth: Swift.Int)] = [(root, 0)]

    while !queue.isEmpty {
      let (current, depth) = queue.removeFirst()

      if hasManifest(in: current) {
        found.append(current)
        continue
      }

      guard depth < maxDepth else { continue }

      let entries: [File.Directory.Entry]
      do throws(File.Directory.Contents.Error) {
        entries = try File.Directory(current).entries()
      } catch {
        continue
      }

      for entry in entries where entry.type == .directory {
        guard let nameString = Swift.String(entry.name),
          !nameString.hasPrefix(".")
        else { continue }

        let component: File.Path.Component
        do throws(Paths.Path.Component.Error) {
          component = try entry.name.asPathComponent()
        } catch {
          continue
        }
        queue.append((current / component, depth + 1))
      }
    }
    return found
  }
}

// MARK: - Subprocess + decode (private)

extension Package.Workspace {
  /// Default `swift` executable resolution — `/usr/bin/env` so the
  /// child does the `$PATH` lookup. Callers needing a pinned
  /// toolchain set ``Configuration/swiftExecutable``.
  private static func defaultSwiftExecutable() -> Paths.Path {
    "/usr/bin/env"
  }

  /// Spawn `swift package dump-package` in `packageDirectory`,
  /// capture stdout, decode as `Package.Manifest`.
  private static func loadManifest(
    packageDirectory: Paths.Path,
    swiftExecutable: Paths.Path
  ) throws(Self.Error) -> Package.Manifest {
    let executableString = swiftExecutable.string
    let configuration = Process.Spawn.Configuration(
      executable: executableString,
      arguments: executableString == "/usr/bin/env"
        ? ["swift", "package", "dump-package"]
        : ["package", "dump-package"],
      stdout: .pipe,
      stderr: .pipe,
      workingDirectory: packageDirectory.string
    )

    let output: Process.Output
    do {
      output = try Process.Spawn.run(configuration)
    } catch {
      throw .init(
        kind: .subprocessError,
        detail: "spawn failed for '\(packageDirectory.string)': \(error)"
      )
    }

    guard case .exited(let code) = output.status, code == 0 else {
      let stderrSummary =
        output.stderr.map {
          Swift.String(decoding: $0, as: Unicode.UTF8.self)
        } ?? ""
      throw .init(
        kind: .manifestLoadFailed,
        detail:
          "'\(packageDirectory.string)' exited with non-zero status: \(output.status). stderr: \(stderrSummary)"
      )
    }

    guard let stdoutBytes = output.stdout else {
      throw .init(
        kind: .manifestLoadFailed,
        detail: "'\(packageDirectory.string)' produced no stdout (pipe was not captured)"
      )
    }

    do {
      return try Package.Manifest.decode(jsonBytes: stdoutBytes.map(Byte.init))
    } catch {
      throw .init(
        kind: .invalidManifestJSON,
        detail: "'\(packageDirectory.string)' JSON decode failed: \(error)"
      )
    }
  }

  /// Load manifests in parallel with a concurrency bound, in
  /// chunks of `concurrencyBound`. Per-chunk results are sorted
  /// back into filesystem-walk order before concatenation.
  private static func loadManifests(
    packageDirectories: [Paths.Path],
    swiftExecutable: Paths.Path,
    concurrencyBound: Swift.Int
  ) async throws(Self.Error) -> [Package.Manifest] {
    var results: [Package.Manifest] = []
    var index = 0
    while index < packageDirectories.count {
      let upperIndex = Swift.min(index + concurrencyBound, packageDirectories.count)
      let chunk = Swift.Array(packageDirectories[index..<upperIndex])
      let chunkResults = try await loadChunk(chunk, swiftExecutable: swiftExecutable)
      results.append(contentsOf: chunkResults)
      index = upperIndex
    }
    return results
  }

  /// Spawn `swift package dump-package` for every directory in
  /// `chunk` concurrently; collect manifests in input order.
  ///
  /// Swift 6.3's `withThrowingTaskGroup` does not accept a typed
  /// `Failure` parameter — its body and iteration always throw
  /// `any Error`. The TaskGroup is therefore the one untyped-throws
  /// boundary in this pipeline; we bridge here so the helper's
  /// public-facing signature remains typed.
  private static func loadChunk(
    _ chunk: [Paths.Path], swiftExecutable: Paths.Path
  ) async throws(Self.Error) -> [Package.Manifest] {
    let exec = swiftExecutable
    do {
      return try await withThrowingTaskGroup(
        of: (Swift.Int, Package.Manifest).self
      ) { group in
        for (offset, directory) in chunk.enumerated() {
          group.addTask {
            let manifest = try loadManifest(
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
    } catch let error as Self.Error {
      throw error
    } catch is CancellationError {
      throw .init(
        kind: .subprocessError,
        detail: "concurrent manifest load cancelled"
      )
    } catch {
      throw .init(
        kind: .subprocessError,
        detail: "unexpected error during concurrent manifest load: \(error)"
      )
    }
  }
}
