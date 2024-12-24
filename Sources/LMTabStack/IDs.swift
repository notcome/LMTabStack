public struct AnyTabID: Hashable, Sendable {
    var storage: AnySendableHashable

    public var base: any Hashable & Sendable {
        storage.base
    }

    public init(_ value: some Hashable & Sendable) {
        storage = .init(base: value)
    }
}

public struct AnyPageID: Hashable, Sendable {
    var storage: AnySendableHashable

    public var base: any Hashable & Sendable {
        storage.base
    }

    public init(_ value: some Hashable & Sendable) {
        storage = .init(base: value)
    }
}

public struct AnyTransitionElementID: Hashable, Sendable {
    var storage: AnySendableHashable

    public var base: any Hashable & Sendable {
        storage.base
    }

    public init(_ value: some Hashable & Sendable) {
        storage = .init(base: value)
    }
}
