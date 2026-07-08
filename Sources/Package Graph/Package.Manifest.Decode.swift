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

// Hand-rolled walker over `swift package dump-package` JSON output via
// swift-json. Foundation-free: no `import Foundation`, no `JSONDecoder`.
//
// Wire-format shape — mirrors the user-facing surface documented in
// swift-spm-standard's `Package.Manifest+Codable.swift`. Only the v0.2
// fields needed by ``Package/Workspace/discover`` are walked here
// (``name``, ``toolsVersion``, ``dependencies``). The v0.3 fields
// (``products``, ``targets``, ``platforms``) are silently ignored —
// `Package.Manifest`'s init carries defaults for them, and graph
// queries do not consume them. Consumers needing the full v0.3
// surface should decode via the swift-spm-standard Codable
// conformance using a Foundation-free encoder (out of v0.2 scope).

internal import Byte_Primitive
internal import JSON

extension Package.Manifest {
  /// Decode a `Package.Manifest` from `swift package dump-package`
  /// JSON output via swift-json's `JSON.parse` + a hand-rolled walker.
  ///
  /// - Parameter bytes: UTF-8 JSON bytes (typically captured stdout
  ///   from a `swift package dump-package` subprocess).
  /// - Returns: The decoded manifest. v0.3 fields default if absent.
  /// - Throws: `JSON.Error` on parse failure or wire-shape mismatch.
  internal static func decode(jsonBytes bytes: [Byte]) throws(JSON.Error) -> Package.Manifest {
    let json: JSON = try JSON.parse(bytes)
    return try _decode(json: json)
  }

  private static func _decode(json: JSON) throws(JSON.Error) -> Package.Manifest {
    guard json.isObject else {
      throw .typeMismatch(expected: "Manifest object", got: "non-object JSON value")
    }

    let nameValue = json["name"]
    guard nameValue.isString else { throw .missingKey("name") }
    let name = Package.Name(_unchecked: Swift.String(nameValue))

    let toolsValue = json["toolsVersion"]
    let versionValue = toolsValue["_version"]
    guard versionValue.isString else { throw .missingKey("toolsVersion._version") }
    let versionString = Swift.String(versionValue)
    let toolsVersion: Version.Tools
    do throws(Version.Tools.Error) {
      toolsVersion = try Version.Tools(parsing: versionString)
    } catch {
      throw .typeMismatch(
        expected: "valid swift-tools-version (e.g. \"6.3.1\")",
        got: versionString
      )
    }

    guard let dependenciesArray = json["dependencies"].array else {
      throw .missingKey("dependencies")
    }
    var dependencies: [Package.Dependency] = []
    dependencies.reserveCapacity(dependenciesArray.count)
    for entry in dependenciesArray {
      dependencies.append(try _decodeDependency(entry))
    }

    return Package.Manifest(
      name: name,
      toolsVersion: toolsVersion,
      dependencies: dependencies
    )
  }

  private static func _decodeDependency(_ json: JSON) throws(JSON.Error) -> Package.Dependency {
    guard json.isObject else {
      throw .typeMismatch(expected: "dependency object", got: "non-object JSON value")
    }

    if let fileSystem = json["fileSystem"].array, let record = fileSystem.first {
      let identityValue = record["identity"]
      guard identityValue.isString else { throw .missingKey("fileSystem.identity") }
      let pathValue = record["path"]
      guard pathValue.isString else { throw .missingKey("fileSystem.path") }
      let pathString = Swift.String(pathValue)
      let path: Paths.Path
      do throws(Paths.Path.Error) {
        path = try Paths.Path(pathString)
      } catch {
        throw .typeMismatch(
          expected: "valid filesystem path",
          got: pathString
        )
      }
      return Package.Dependency(
        source: .path(path),
        name: Package.Name(_unchecked: Swift.String(identityValue)),
        products: []
      )
    }

    if let sourceControl = json["sourceControl"].array, let record = sourceControl.first {
      let identityValue = record["identity"]
      guard identityValue.isString else { throw .missingKey("sourceControl.identity") }
      let identity = Swift.String(identityValue)
      let location = record["location"]
      let remoteArray = location["remote"].array ?? []
      let urlString: Swift.String
      if let firstRemote = remoteArray.first {
        let urlValue = firstRemote["urlString"]
        guard urlValue.isString else {
          throw .missingKey("sourceControl.location.remote.urlString")
        }
        urlString = Swift.String(urlValue)
      } else {
        urlString = ""
      }
      let url: URI
      do throws(URIError) {
        url = try URI(urlString)
      } catch {
        throw .typeMismatch(
          expected: "valid URI per RFC 3986",
          got: urlString
        )
      }
      let requirement = try _decodeRequirement(record["requirement"])
      return Package.Dependency(
        source: .url(url, requirement),
        name: Package.Name(_unchecked: identity),
        products: []
      )
    }

    if let registry = json["registry"].array, let record = registry.first {
      let identityValue = record["identity"]
      guard identityValue.isString else { throw .missingKey("registry.identity") }
      let identityString = Swift.String(identityValue)
      let parsedIdentity = try _parseIdentity(identityString)
      let requirement = try _decodeRequirement(record["requirement"])
      return Package.Dependency(
        source: .registry(parsedIdentity, requirement),
        name: Package.Name(_unchecked: identityString),
        products: []
      )
    }

    throw .typeMismatch(
      expected: "fileSystem|sourceControl|registry dependency",
      got: "object with none of those discriminator keys"
    )
  }

  private static func _decodeRequirement(_ json: JSON) throws(JSON.Error) -> Package.Requirement {
    guard json.isObject else {
      throw .typeMismatch(expected: "requirement object", got: "non-object JSON value")
    }

    if let exactArray = json["exact"].array, let entry = exactArray.first {
      guard entry.isString else { throw .missingKey("exact[0]") }
      let version = try _parseSemantic(Swift.String(entry))
      return .exact(version)
    }
    if let rangeArray = json["range"].array, let entry = rangeArray.first {
      let lowerValue = entry["lowerBound"]
      guard lowerValue.isString else { throw .missingKey("range.lowerBound") }
      let upperValue = entry["upperBound"]
      guard upperValue.isString else { throw .missingKey("range.upperBound") }
      let lower = try _parseSemantic(Swift.String(lowerValue))
      let upper = try _parseSemantic(Swift.String(upperValue))
      return lower..<upper
    }
    if let branchArray = json["branch"].array, let entry = branchArray.first {
      guard entry.isString else { throw .missingKey("branch[0]") }
      return .branch(Swift.String(entry))
    }
    if let revisionArray = json["revision"].array, let entry = revisionArray.first {
      guard entry.isString else { throw .missingKey("revision[0]") }
      return .revision(Swift.String(entry))
    }

    throw .typeMismatch(
      expected: "exact|range|branch|revision requirement",
      got: "object with none of those discriminator keys"
    )
  }

  private static func _parseSemantic(_ string: Swift.String) throws(JSON.Error) -> Version.Semantic
  {
    do throws(Version.Semantic.Error) {
      return try Version.Semantic(parsing: string)
    } catch {
      throw .typeMismatch(
        expected: "valid SemVer (e.g. \"1.2.3\")",
        got: string
      )
    }
  }

  private static func _parseIdentity(_ string: Swift.String) throws(JSON.Error) -> Package.Identity
  {
    guard let dot = string.firstIndex(of: ".") else {
      throw .typeMismatch(
        expected: "registry identity 'scope.name' per SE-0292",
        got: string
      )
    }
    let scope = Swift.String(string[..<dot])
    let name = Swift.String(string[string.index(after: dot)...])
    return Package.Identity(scope: scope, name: name)
  }
}
