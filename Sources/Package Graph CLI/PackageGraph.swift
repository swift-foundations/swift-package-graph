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

internal import Command
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
/// Argument parsing uses `swift-arguments` (the institute's L3 argument
/// parser) per swift-arguments v1.0.9.
///
/// Subcommands:
///
/// ```
/// package-graph dependents-of <package> [--depth N]
/// package-graph dependencies-of <package>
/// package-graph topo
/// package-graph cycles
/// package-graph scc
/// package-graph dot
/// package-graph list
/// ```
///
/// Global flags (per-subcommand):
///
/// ```
/// --root <path>    workspace root (default $PWD)
/// --help / -h      show usage
/// ```
enum PackageGraph: Command.`Protocol`, Equatable {
  case list(List)
  case topo(Topo)
  case cycles(Cycles)
  case scc(SCC)
  case dot(Dot)
  case dependentsOf(DependentsOf)
  case dependenciesOf(DependenciesOf)
}

extension PackageGraph {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "package-graph",
      abstract: "Inspect SwiftPM package dependency graphs."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Subcommand.Group {
        Command.Subcommand.Case(
          "list",
          help: .init(abstract: "List discovered packages."),
          initial: { List() },
          map: Self.list
        )
        Command.Subcommand.Case(
          "topo",
          help: .init(abstract: "Topological order (dependencies first)."),
          initial: { Topo() },
          map: Self.topo
        )
        Command.Subcommand.Case(
          "cycles",
          help: .init(abstract: "List dependency cycles."),
          initial: { Cycles() },
          map: Self.cycles
        )
        Command.Subcommand.Case(
          "scc",
          help: .init(abstract: "Strongly connected components."),
          initial: { SCC() },
          map: Self.scc
        )
        Command.Subcommand.Case(
          "dot",
          help: .init(abstract: "Emit GraphViz DOT."),
          initial: { Dot() },
          map: Self.dot
        )
        Command.Subcommand.Case(
          "dependents-of",
          help: .init(abstract: "List packages depending on <package>."),
          initial: { DependentsOf() },
          map: Self.dependentsOf
        )
        Command.Subcommand.Case(
          "dependencies-of",
          help: .init(abstract: "List packages <package> depends on."),
          initial: { DependenciesOf() },
          map: Self.dependenciesOf
        )
      }
    }
  }

  mutating func run() async throws(Command.Error) {
    switch self {
    case .list(var c):
      try await c.run()
      self = .list(c)

    case .topo(var c):
      try await c.run()
      self = .topo(c)

    case .cycles(var c):
      try await c.run()
      self = .cycles(c)

    case .scc(var c):
      try await c.run()
      self = .scc(c)

    case .dot(var c):
      try await c.run()
      self = .dot(c)

    case .dependentsOf(var c):
      try await c.run()
      self = .dependentsOf(c)

    case .dependenciesOf(var c):
      try await c.run()
      self = .dependenciesOf(c)
    }
  }
}

// MARK: - Shared helpers

extension PackageGraph {
  /// Loads the workspace + graph, mapping errors to documented exit codes.
  fileprivate static func loadGraph(at root: Paths.Path) async -> Package.Graph {
    do {
      let workspace = try await Package.Workspace.discover(at: root)
      return try Package.Graph(workspace)
    } catch let error as Package.Workspace.Error {
      printError("package-graph: workspace error (\(error.kind)): \(error.detail)")
      platformExit(2)
    } catch let error as Package.Graph.Error {
      printError("package-graph: graph error: \(error)")
      platformExit(3)
    } catch {
      printError("package-graph: \(error)")
      platformExit(4)
    }
  }

  /// Resolves the workspace root from an override string, falling back to PWD.
  ///
  /// An empty `override` is treated as "not provided" — the schema-bound
  /// default for `--root` is empty per [PRIM-FOUND] no-Optional constraint
  /// on swift-arguments v1.0.9 `Command.Option<Root, V>` (V must conform
  /// to `Argument.Codable` and `Optional<String>` does not).
  fileprivate static func resolveRoot(_ override: Swift.String) -> Paths.Path {
    let rootString: Swift.String
    if override.isEmpty {
      rootString = unsafe currentWorkingDirectory()
    } else {
      rootString = override
    }
    do {
      return try Paths.Path(rootString)
    } catch {
      printError("package-graph: invalid root path '\(rootString)': \(error)")
      platformExit(2)
    }
  }

  @unsafe
  fileprivate static func currentWorkingDirectory() -> Swift.String {
    var buffer = [CChar](repeating: 0, count: 4096)
    let cwd = unsafe getcwd(&buffer, buffer.count)
    guard let cwdPtr = unsafe cwd else { return "." }
    return unsafe Swift.String(cString: cwdPtr)
  }

  fileprivate static func printError(_ message: Swift.String) {
    // Stderr would be preferable; the prior implementation used `print`
    // (stdout). Preserve that behavior to keep migration additive.
    print(message)
  }

  fileprivate static func platformExit(_ code: Swift.Int32) -> Never {
    exit(code)
  }
}

// MARK: - Long-option name constants
//
// Production `Argument.Name.Long` factory is throwing (validates against
// `[a-zA-Z][a-zA-Z0-9-]*`). Per-call `try` would scatter throw-noise; build
// once at module-load with `_unchecked` since the literals are known-good.

private enum Names {}

extension Names {
  static let root: Argument.Name = .long(Argument.Name.Long(_unchecked: "root"))
  static let depth: Argument.Name = .long(Argument.Name.Long(_unchecked: "depth"))
}

// MARK: - Subcommands

extension PackageGraph {
  struct List: Command.`Protocol`, Equatable {
    var root: Swift.String

    init(root: Swift.String = "") {
      self.root = root
    }
  }

  struct Topo: Command.`Protocol`, Equatable {
    var root: Swift.String

    init(root: Swift.String = "") {
      self.root = root
    }
  }

  struct Cycles: Command.`Protocol`, Equatable {
    var root: Swift.String

    init(root: Swift.String = "") {
      self.root = root
    }
  }

  struct SCC: Command.`Protocol`, Equatable {
    var root: Swift.String

    init(root: Swift.String = "") {
      self.root = root
    }
  }

  struct Dot: Command.`Protocol`, Equatable {
    var root: Swift.String

    init(root: Swift.String = "") {
      self.root = root
    }
  }

  struct DependentsOf: Command.`Protocol`, Equatable {
    var package: Swift.String
    var root: Swift.String
    var depth: Swift.Int

    init(
      package: Swift.String = "",
      root: Swift.String = "",
      depth: Swift.Int = Swift.Int.max
    ) {
      self.package = package
      self.root = root
      self.depth = depth
    }
  }

  struct DependenciesOf: Command.`Protocol`, Equatable {
    var package: Swift.String
    var root: Swift.String

    init(
      package: Swift.String = "",
      root: Swift.String = ""
    ) {
      self.package = package
      self.root = root
    }
  }
}

extension PackageGraph.List {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "list",
      abstract: "List discovered packages."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    for name in graph.packages.sorted() {
      print(name)
    }
  }
}

extension PackageGraph.Topo {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "topo",
      abstract: "Topological order (dependencies first)."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    do {
      let order = try graph.topologicalOrder()
      for name in order {
        print(name)
      }
    } catch {
      PackageGraph.printError("package-graph: graph error: \(error)")
      PackageGraph.platformExit(3)
    }
  }
}

extension PackageGraph.Cycles {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "cycles",
      abstract: "List dependency cycles."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
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

extension PackageGraph.SCC {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "scc",
      abstract: "Strongly connected components."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    let components = graph.stronglyConnectedComponents()
    for component in components {
      print(component.map { "\($0)" }.sorted().joined(separator: ", "))
    }
  }
}

extension PackageGraph.Dot {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "dot",
      abstract: "Emit GraphViz DOT."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    print(graph.dot())
  }
}

extension PackageGraph.DependentsOf {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "dependents-of",
      abstract: "List packages depending on <package>."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Positional(
        \.package,
        name: "package",
        help: .init(abstract: "Upstream package name.")
      )
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
      Command.Option(
        \.depth,
        name: Names.depth,
        help: .init(abstract: "Wave depth (default .max).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    let waves = graph.transitiveDependents(
      of: Package.Name(_unchecked: package),
      depth: depth
    )
    for wave in waves {
      for name in wave.packages.sorted() {
        print("[\(wave.depth)] \(name)")
      }
    }
  }
}

extension PackageGraph.DependenciesOf {
  static var configuration: Command.Configuration {
    Command.Configuration(
      name: "dependencies-of",
      abstract: "List packages <package> depends on."
    )
  }

  static var schema: Command.Schema.Definition<Self> {
    Command.Schema.Definition<Self> {
      Command.Positional(
        \.package,
        name: "package",
        help: .init(abstract: "Downstream package name.")
      )
      Command.Option(
        \.root,
        name: Names.root,
        help: .init(abstract: "Workspace root (default $PWD).")
      )
    }
  }

  mutating func run() async throws(Command.Error) {
    let rootPath = PackageGraph.resolveRoot(root)
    let graph = await PackageGraph.loadGraph(at: rootPath)
    let dependencies = graph.transitiveDependencies(
      of: Package.Name(_unchecked: package)
    )
    for name in dependencies.sorted() {
      print(name)
    }
  }
}

// MARK: - Entry point

@main
enum Main {}

extension Main {
  static func main() async {
    let argv = Array(CommandLine.arguments.dropFirst())
    do {
      var cmd = try Command.parse(
        PackageGraph.self,
        from: argv,
        initial: .list(.init())
      )
      try await cmd.run()
    } catch {
      handle(error)
    }
  }

  private static func handle(_ error: Command.Error) -> Never {
    switch error {
    case .helpRequested:
      // Render top-level help.
      var buffer = ""
      Command.Help<PackageGraph>().serialize(PackageGraph.schema, into: &buffer)
      print(buffer)
      exit(0)

    case .helpRequestedForSubcommand(_, let rendered):
      print(rendered)
      exit(0)

    case .missingSubcommand(let available):
      print(
        "package-graph: missing subcommand. Expected one of: \(available.joined(separator: ", "))")
      exit(64)

    case .versionRequested(let version):
      print(version)
      exit(0)

    case .exit(let code, let message):
      if let message { print(message) }
      exit(code)

    case .invalidEnvironmentValue(let name, let environment, let value):
      print(
        "package-graph: invalid value '\(value)' for '\(name)' from environment variable '\(environment)'"
      )
      exit(64)

    case .unknownSubcommand(let name, _, _):
      print("package-graph: unknown subcommand '\(name)'")
      exit(64)

    case .unknownLongOption(let name, _, _):
      print("package-graph: unknown option '--\(name)'")
      exit(64)

    case .unknownShortOption(let name, _):
      print("package-graph: unknown option '-\(name)'")
      exit(64)

    case .missingOptionValue(let name, _):
      print("package-graph: option '--\(name)' requires a value")
      exit(64)

    case .invalidValue(let name, let value, _):
      print("package-graph: invalid value '\(value)' for option '\(name)'")
      exit(64)

    case .missingPositional(let name, _):
      print("package-graph: missing required argument '\(name)'")
      exit(64)

    case .unexpectedPositional(let value, _):
      print("package-graph: unexpected argument '\(value)'")
      exit(64)

    case .validationFailed(let reason):
      print("package-graph: \(reason)")
      exit(64)

    case .argument(let error):
      print("package-graph: \(error)")
      exit(64)

    case .tokenizer(let reason, _):
      print("package-graph: \(reason)")
      exit(64)
    }
  }
}
