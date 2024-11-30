@propertyWrapper
struct EqualityIgnored<Value>: Equatable {
    var wrappedValue: Value

    static func == (lhs: Self, rhs: Self) -> Bool {
        // Always return true, ignoring the actual value.
        true
    }
}

struct Unequal: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        false
    }
}

private func areEqual<LHS: Equatable>(lhs: LHS, rhs: any Equatable) -> Bool {
    guard let rhs = rhs as? LHS else { return false }
    return lhs == rhs
}

struct AnySendableEquatable: Equatable, Sendable {
    var base: any Equatable & Sendable

    init(base: some Equatable & Sendable) {
        self.base = base
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        areEqual(lhs: lhs.base, rhs: rhs.base)
    }
}

func updateIfNeeded<T: Equatable>(_ destination: inout T, to newValue: T) {
    guard destination != newValue else { return }
    destination = newValue
}

struct AnySendableHashable: Hashable, Sendable {
    var base: any Hashable & Sendable

    static func ==(lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }
}
