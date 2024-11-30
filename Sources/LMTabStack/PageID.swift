public struct AnyPageID: Hashable, Sendable {
    public let base: any Hashable & Sendable

    public init(_ value: some Hashable & Sendable) {
        self.base = value
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }
}

public struct AnyTabID: Hashable, Sendable {
    public let base: any Hashable & Sendable

    public init(_ value: some Hashable & Sendable) {
        self.base = value
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }
}
