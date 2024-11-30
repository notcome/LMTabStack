import SwiftUI

public struct AnyTransitionElementID: Hashable, Sendable {
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

struct TransitionElementSummary: Equatable {
    var elements: [AnyTransitionElementID: Anchor<CGRect>] = [:]

    mutating func merge(_ other: TransitionElementSummary) {
        for (id, anchor) in other.elements {
            elements[id] = anchor
        }
    }
}

extension TransitionElementSummary: PreferenceKey {
    static var defaultValue: Self { .init() }

    static func reduce(value: inout TransitionElementSummary, nextValue: () -> TransitionElementSummary) {
        value.merge(nextValue())
    }
}

private struct TransitionElementModifier: ViewModifier {
    var id: AnyTransitionElementID

    @Environment(PageHostingStore.self)
    private var store

    func body(content: Content) -> some View {
        Color.clear
            .overlay {
                let effects = store.transitionElements[id: id]?.transitionEffects
                content
                    .modifier(effects ?? .init())
            }
            .anchorPreference(key: TransitionElementSummary.self, value: .bounds) { anchor in
                var summary = TransitionElementSummary()
                summary.elements[id] = anchor
                return summary
            }
    }
}

extension View {
    public func transitionElement(id: some Hashable & Sendable) -> some View {
        modifier(TransitionElementModifier(id: AnyTransitionElementID(id)))
    }
}
