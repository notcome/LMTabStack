import SwiftUI

struct TransitionElementSummary: Equatable {
    var transitionToken: Int?
    var pageAnchor: Anchor<CGRect>?
    var elements: [AnyTransitionElementID: Anchor<CGRect>] = [:]
    var morphables: [AnyMorphableID: Anchor<CGRect>] = [:]

    mutating func merge(_ other: TransitionElementSummary) {
        if let otherToken = other.transitionToken {
            if let currentToken = transitionToken {
                transitionToken = max(currentToken, otherToken)
            } else {
                transitionToken = otherToken
            }
        }
        if let pageAnchor = other.pageAnchor {
            self.pageAnchor = pageAnchor
        }
        for (id, anchor) in other.elements {
            elements[id] = anchor
        }
        for (id, anchor) in other.morphables {
            morphables[id] = anchor
        }
    }
}

extension TransitionElementSummary: PreferenceKey {
    static var defaultValue: Self { .init() }

    static func reduce(value: inout TransitionElementSummary, nextValue: () -> TransitionElementSummary) {
        value.merge(nextValue())
    }
}
