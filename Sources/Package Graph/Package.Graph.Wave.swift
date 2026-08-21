extension Package.Graph {

    public struct Wave: Swift.Sendable, Swift.Hashable {

        public let depth: Swift.Int

        public let packages: Swift.Set<Package.Name>

        public init(depth: Swift.Int, packages: Swift.Set<Package.Name>) {
            self.depth = depth
            self.packages = packages
        }
    }
}
