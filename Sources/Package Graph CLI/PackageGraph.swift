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
/// Hand-rolled argument parsing per the L1/L2 split research doc; no
/// `apple/swift-argument-parser` dependency. The migration target is the
/// future `swift-command-line-interface` L3 foundation when it lands per
/// rewritten `[RES-018]` case (c) — see HANDOFF Architectural Note.
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
struct PackageGraph {
    static func main() async {
        let arguments = Swift.Array(CommandLine.arguments.dropFirst())

        guard let subcommand = arguments.first else {
            usage()
            exit(1)
        }

        if subcommand == "--help" || subcommand == "-h" || subcommand == "help" {
            usage()
            exit(0)
        }

        let rootString: Swift.String
        if let parsedRoot = parseRoot(arguments) {
            rootString = parsedRoot
        } else {
            rootString = unsafe currentWorkingDirectory()
        }
        let root: Paths.Path
        do {
            root = try Paths.Path(rootString)
        } catch {
            print("package-graph: invalid root path '\(rootString)': \(error)")
            exit(2)
        }

        do {
            let workspace = try await Package.Workspace.discover(at: root)
            let graph = try Package.Graph(workspace)

            switch subcommand {
            case "list":
                for name in graph.packages.sorted() {
                    print(name)
                }
            case "topo":
                let order = try graph.topologicalOrder()
                for name in order {
                    print(name)
                }
            case "cycles":
                let cycles = graph.cycles()
                if cycles.isEmpty {
                    print("(no cycles)")
                } else {
                    for cycle in cycles {
                        print(cycle.nodes.map { "\($0)" }.joined(separator: " -> "))
                    }
                }
            case "scc":
                let components = graph.stronglyConnectedComponents()
                for component in components {
                    print(component.map { "\($0)" }.sorted().joined(separator: ", "))
                }
            case "dot":
                print(graph.dot())
            case "dependents-of":
                guard arguments.count >= 2 else {
                    print("package-graph: 'dependents-of' requires a <package> argument")
                    exit(1)
                }
                let depth = parseDepth(arguments) ?? Swift.Int.max
                let waves = graph.transitiveDependents(
                    of: Package.Name(_unchecked: arguments[1]), depth: depth
                )
                for wave in waves {
                    for name in wave.packages.sorted() {
                        print("[\(wave.depth)] \(name)")
                    }
                }
            case "dependencies-of":
                guard arguments.count >= 2 else {
                    print("package-graph: 'dependencies-of' requires a <package> argument")
                    exit(1)
                }
                let dependencies = graph.transitiveDependencies(
                    of: Package.Name(_unchecked: arguments[1])
                )
                for name in dependencies.sorted() {
                    print(name)
                }
            default:
                print("package-graph: unknown subcommand '\(subcommand)'")
                usage()
                exit(1)
            }
        } catch let error as Package.Workspace.Error {
            print("package-graph: workspace error (\(error.kind)): \(error.detail)")
            exit(2)
        } catch let error as Package.Graph.Error {
            print("package-graph: graph error: \(error)")
            exit(3)
        } catch {
            print("package-graph: \(error)")
            exit(4)
        }
    }

    private static func usage() {
        print("""
        Usage: package-graph <subcommand> [options]

        Subcommands:
          dependents-of <package> [--depth N]    list packages depending on <package>
          dependencies-of <package> [--depth N]  list packages <package> depends on
          topo                                   topological order (dependencies first)
          cycles                                 list dependency cycles
          scc                                    strongly connected components
          dot                                    emit GraphViz DOT
          list                                   list discovered packages

        Global options:
          --root <path>    workspace root (default $PWD)
          --help / -h      show this help
        """)
    }

    private static func parseRoot(_ arguments: [Swift.String]) -> Swift.String? {
        guard let index = arguments.firstIndex(of: "--root"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }

    private static func parseDepth(_ arguments: [Swift.String]) -> Swift.Int? {
        guard let index = arguments.firstIndex(of: "--depth"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return Swift.Int(arguments[index + 1])
    }

    @unsafe
    private static func currentWorkingDirectory() -> Swift.String {
        var buffer = [CChar](repeating: 0, count: 4096)
        let cwd = unsafe getcwd(&buffer, buffer.count)
        guard let cwdPtr = unsafe cwd else { return "." }
        return unsafe Swift.String(cString: cwdPtr)
    }
}
