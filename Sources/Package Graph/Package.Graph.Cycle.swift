extension Package.Graph {

    public struct Cycle: Swift.Sendable, Swift.Hashable {

        public let nodes: [Package.Name]

        public init(nodes: [Package.Name]) {
            self.nodes = nodes
        }
    }
}
