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

internal import Package_Graph
internal import Paths
internal import ArgumentParser

#if canImport(Darwin)
internal import Darwin
#elseif canImport(Glibc)
internal import Glibc
#elseif canImport(Musl)
internal import Musl
#elseif canImport(WinSDK)
internal import WinSDK
#endif

/// Command-line entry point for the `package-graph` executable.
///
/// Argument parsing uses `apple/swift-argument-parser`, the canonical
/// institute pattern for CLI argument parsing per swift-console research
/// v3.0.1 (2026-04-01) — argument parsing is a deliberate non-goal for
/// swift-console.
///
/// Subcommands:
///
/// ```
/// package-graph dependents-of <package> [--depth N]
/// package-graph dependencies-of <package> [--depth N]
/// package-graph topo
/// package-graph cycles
/// package-graph scc
/// package-graph dot
/// package-graph list
/// ```
///
/// Global flags:
///
/// ```
/// --root <path>    workspace root (default $PWD)
/// --help / -h      show usage
/// ```
@main
struct PackageGraph: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package-graph",
        abstract: "Inspect SwiftPM package dependency graphs.",
        subcommands: [
            List.self,
            Topo.self,
            Cycles.self,
            SCC.self,
            Dot.self,
            DependentsOf.self,
            DependenciesOf.self
        ]
    )

    /// Global options shared across subcommands.
    struct Options: ParsableArguments {
        @Option(name: .long, help: "Workspace root (default $PWD).")
        var root: Swift.String?

        func resolveRoot() throws -> Paths.Path {
            let rootString: Swift.String
            if let root {
                rootString = root
            } else {
                rootString = unsafe currentWorkingDirectory()
            }
            do {
                return try Paths.Path(rootString)
            } catch {
                print("package-graph: invalid root path '\(rootString)': \(error)")
                throw ExitCode(2)
            }
        }
    }

    /// Loads the workspace + graph, mapping errors to documented exit codes.
    static func loadGraph(at root: Paths.Path) async throws -> Package.Graph {
        do {
            let workspace = try await Package.Workspace.discover(at: root)
            return try Package.Graph(workspace)
        } catch let error as Package.Workspace.Error {
            print("package-graph: workspace error (\(error.kind)): \(error.detail)")
            throw ExitCode(2)
        } catch let error as Package.Graph.Error {
            print("package-graph: graph error: \(error)")
            throw ExitCode(3)
        } catch {
            print("package-graph: \(error)")
            throw ExitCode(4)
        }
    }

    @unsafe
    private static func currentWorkingDirectory() -> Swift.String {
        var buffer = [CChar](repeating: 0, count: 4096)
        let cwd = unsafe getcwd(&buffer, buffer.count)
        guard let cwdPtr = unsafe cwd else { return "." }
        return unsafe Swift.String(cString: cwdPtr)
    }
}

extension PackageGraph {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List discovered packages."
        )

        @OptionGroup var options: PackageGraph.Options

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            for name in graph.packages.sorted() {
                print(name)
            }
        }
    }

    struct Topo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "topo",
            abstract: "Topological order (dependencies first)."
        )

        @OptionGroup var options: PackageGraph.Options

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            do {
                let order = try graph.topologicalOrder()
                for name in order {
                    print(name)
                }
            } catch {
                print("package-graph: graph error: \(error)")
                throw ExitCode(3)
            }
        }
    }

    struct Cycles: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cycles",
            abstract: "List dependency cycles."
        )

        @OptionGroup var options: PackageGraph.Options

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            let cycles = graph.cycles()
            if cycles.isEmpty {
                print("(no cycles)")
            } else {
                for cycle in cycles {
                    print(cycle.nodes.map { "\($0)" }.joined(separator: " -> "))
                }
            }
        }
    }

    struct SCC: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "scc",
            abstract: "Strongly connected components."
        )

        @OptionGroup var options: PackageGraph.Options

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            let components = graph.stronglyConnectedComponents()
            for component in components {
                print(component.map { "\($0)" }.sorted().joined(separator: ", "))
            }
        }
    }

    struct Dot: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dot",
            abstract: "Emit GraphViz DOT."
        )

        @OptionGroup var options: PackageGraph.Options

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            print(graph.dot())
        }
    }

    struct DependentsOf: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dependents-of",
            abstract: "List packages depending on <package>."
        )

        @OptionGroup var options: PackageGraph.Options

        @Argument(help: "Upstream package name.")
        var package: Swift.String

        @Option(name: .long, help: "Wave depth (default .max).")
        var depth: Swift.Int?

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            let waves = graph.transitiveDependents(
                of: Package.Name(_unchecked: package),
                depth: depth ?? Swift.Int.max
            )
            for wave in waves {
                for name in wave.packages.sorted() {
                    print("[\(wave.depth)] \(name)")
                }
            }
        }
    }

    struct DependenciesOf: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dependencies-of",
            abstract: "List packages <package> depends on."
        )

        @OptionGroup var options: PackageGraph.Options

        @Argument(help: "Downstream package name.")
        var package: Swift.String

        func run() async throws {
            let root = try options.resolveRoot()
            let graph = try await PackageGraph.loadGraph(at: root)
            let dependencies = graph.transitiveDependencies(
                of: Package.Name(_unchecked: package)
            )
            for name in dependencies.sorted() {
                print(name)
            }
        }
    }
}
