extension Package.Graph.Error {

    public enum Kind: Swift.Sendable, Swift.Hashable {

        case constructionFailed

        case cycleDetected
    }
}
