extension Package.Workspace.Error {

    public enum Kind: Swift.Sendable, Swift.Hashable {

        case rootDoesNotExist

        case noPackagesFound

        case manifestLoadFailed

        case invalidManifestJSON

        case subprocessError

    }
}
