import SwiftUI

public protocol InteractiveTransition: AdvancedTransition {
    var isComplete: Bool { get }
}

struct AnyInteractiveTransition: Equatable {
    var id: UUID
    var token = 0

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.token == rhs.token
    }

    private var base: any InteractiveTransition

    init(_ transition: some InteractiveTransition) {
        id = UUID()
        base = transition
    }

    var morphingViews: AnyView {
        base.morphingViews.eraseToAnyView()
    }

    func transitions(morphingViews: MorphingViewsProxy) -> AnyView {
        base.transitions(morphingViews: morphingViews).eraseToAnyView()
    }

    var isComplete: Bool {
        base.isComplete
    }

    mutating func modify<T: InteractiveTransition>(as type: T.Type = T.self, body: (inout T) -> Void) {
        var transition = base as! T
        precondition(!transition.isComplete, "Cannot modify a complete interactive transition.")
        body(&transition)
        token += 1
        base = transition
    }
}
