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

/// v0.1 CLI shell for the `package-graph` executable.
///
/// Hand-rolled argument parsing per the L1/L2 split research doc;
/// no `apple/swift-argument-parser` dependency. Migration target =
/// future `swift-command-line-interface` L3 foundation when it
/// lands.
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
/// --root <path>     workspace root (default $PWD)
/// --json            structured output
/// --help / -h       show usage
/// ```
@main
struct PackageGraph {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()

        guard let subcommand = arguments.first else {
            printUsage()
            exit(1)
        }

        switch subcommand {
        case "--help", "-h", "help":
            printUsage()
            exit(0)
        case "dependents-of", "dependencies-of", "topo", "cycles", "scc", "dot", "list":
            print("package-graph: v0.1 scaffold — \(subcommand) routing pending Package.Workspace.discover production implementation")
            exit(0)
        default:
            print("package-graph: unknown subcommand '\(subcommand)'")
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: package-graph <subcommand> [options]

        Subcommands:
          dependents-of <package> [--depth N]    list packages depending on <package>
          dependencies-of <package> [--depth N]  list packages <package> depends on
          topo                                   topological order
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
}
