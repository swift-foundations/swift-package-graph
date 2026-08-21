extension Package.Graph {

    public struct Error: Swift.Error, Swift.Sendable, Swift.Hashable {
        public let kind: Kind
        public let detail: Swift.String

        public init(kind: Kind, detail: Swift.String = "") {
            self.kind = kind
            self.detail = detail
        }
    }
}
