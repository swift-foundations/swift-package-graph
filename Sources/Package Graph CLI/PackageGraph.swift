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
/// future `swift-command-line-interface` L3 foundation when it lands.
///
/// Subcommands (per the package's design doc Q6):
///
/// ```
/// package-graph dependents-of <package> [--depth N]
/// package-graph dependencies-of <package> [--depth N]
/// package-graph topo
/// package-graph cycles
/// package-graph scc
/// package-graph dot [-o file.dot]
/// package-graph list
/// ```
///
/// Global flags:
///
/// ```
/// --root <path>    workspace root (default $PWD)
/// --json           emit structured output
/// --help / -h      show usage
/// ```
///
/// v0.2 status: subcommand recognition and usage are wired; subcommand
/// execution is gated on ``Package/Workspace/discover(at:configuration:)``
/// which is blocked on swift-process v2 (capture-pipe streams +
/// working-directory). Phase 3 lifts the gate.
@main
struct PackageGraph {
    static func main() {
        let arguments = Swift.Array(CommandLine.arguments.dropFirst())

        guard let subcommand = arguments.first else {
            usage()
            exit(1)
        }

        switch subcommand {
        case "--help", "-h", "help":
            usage()
            exit(0)
        case "dependents-of", "dependencies-of", "topo", "cycles", "scc", "dot", "list":
            phase3Pending(subcommand: subcommand)
            exit(1)
        default:
            print("package-graph: unknown subcommand '\(subcommand)'")
            usage()
            exit(1)
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
          dot [-o file.dot]                      emit GraphViz DOT
          list                                   list discovered packages

        Global options:
          --root <path>    workspace root (default $PWD)
          --json           emit structured output
          --help / -h      show this help
        """)
    }

    private static func phase3Pending(subcommand: Swift.String) {
        print("""
        package-graph: '\(subcommand)' is not yet available.

        The Package.Graph library surface (cycles, topological order, SCC, DOT)
        ships in v0.2 — but reaching it from the CLI requires Workspace.discover
        which is blocked on swift-process v2 (capture-pipe streams +
        working-directory support). Phase 3 lifts the gate.

        In the meantime, depend on Package_Graph from a Swift library or test
        target and construct Package.Workspace / Package.Graph directly.
        """)
    }
}
