import SwiftUI

public protocol AutomaticTransition: AdvancedTransition {
    var progress: TransitionProgress { get set }
}

struct AnyAutomaticTransition: Equatable {
    var id: UUID
    var token = 0

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.token == rhs.token
    }

    private var base: any AutomaticTransition

    init(_ transition: some AutomaticTransition) {
        id = UUID()
        base = transition
    }

    var morphingViews: AnyView {
        base.morphingViews.eraseToAnyView()
    }

    func transitions(morphingViews: MorphingViewsProxy) -> AnyView {
        base.transitions(morphingViews: morphingViews).eraseToAnyView()
    }

    var progress: TransitionProgress {
        get { base.progress }
        set {
            guard base.progress != newValue else { return }
            base.progress = newValue
            token += 1
        }
    }
}
