@propertyWrapper
struct EqualityIgnored<Value>: Equatable {
    var wrappedValue: Value

    static func == (lhs: Self, rhs: Self) -> Bool {
        // Always return true, ignoring the actual value.
        true
    }
}

extension EqualityIgnored where Value == Bool {
    static var dummy: EqualityIgnored<Void> {
        .init(wrappedValue: ())
    }
}

private func areEqual<LHS: Equatable>(lhs: LHS, rhs: any Equatable) -> Bool {
    guard let rhs = rhs as? LHS else { return false }
    return lhs == rhs
}

struct AnyEquatable: Equatable, Sendable {
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
