extension Package.Workspace {

    public struct Configuration: Swift.Sendable, Swift.Hashable {

        public var maxDepth: Swift.Int

        public var maxConcurrentLoads: Swift.Int

        public var swiftExecutable: Paths.Path?

        public init(
            maxDepth: Swift.Int = 2,
            maxConcurrentLoads: Swift.Int = 8,
            swiftExecutable: Paths.Path? = nil
        ) {
            self.maxDepth = maxDepth
            self.maxConcurrentLoads = maxConcurrentLoads
            self.swiftExecutable = swiftExecutable
        }
    }
}
