import ComposableArchitecture
import SwiftUI

public struct TransitioningPages {
    var transitioningPages: IdentifiedArrayOf<PageFeature.State>

    init?(pages: IdentifiedArrayOf<PageFeature.State>) {
        transitioningPages = pages.filter { $0.transitionBehavior != nil }
        guard transitioningPages.allSatisfy(\.hasLoaded) else { return nil }
    }

    public subscript(id id: some Hashable & Sendable) -> PageProxy? {
        assert(type(of: id) != AnyPageID.self, "Argument label \"id\" is required when subscripting with AnyPageID.")
        return self[AnyPageID(id)]
    }

    public subscript(id: AnyPageID) -> PageProxy? {
        transitioningPages[id: id].map(PageProxy.init(state:))
    }
}

public struct PageProxy: Identifiable {
    var state: PageFeature.State

    public var id: AnyPageID {
        state.id
    }
    public var behavior: PageTransitionBehavior {
        state.transitionBehavior!
    }
    public var frame: CGRect {
        state.mountedLayout!.pageFrame
    }

    public var contentView: some View {
        ViewRefView(ref: .content(id))
    }

    public var wrapperView: some View {
        ViewRefView(ref: .wrapper(id))
    }

    public func transitionElement(_ id: some Hashable & Sendable) -> TransitionElementProxy? {
        let id = AnyTransitionElementID(id)
        guard let frame = state.mountedLayout!.transitionElements[id] else { return nil }
        return .init(id: .init(pageID: self.id, elementID: id), frame: frame)
    }
}

public struct TransitionElementProxy: Identifiable {
    public struct ID: Hashable {
        public var pageID: AnyPageID
        public var elementID: AnyTransitionElementID
    }

    public var id: ID
    public var frame: CGRect
}

extension TransitionElementProxy: View {
    public var body: some View {
        ViewRefView(ref: .transitionElement(id))
    }
}


enum TransitionResolver {
    case automatic((TransitioningPages) -> AnyAutomaticTransition)
    case interactive((TransitioningPages) -> AnyInteractiveTransition)
}

struct TransitionUnresolvedState: Equatable {
    var target: IdentifiedArrayOf<GeneratedPage>
    @EqualityIgnored
    var resolver: TransitionResolver
}

public enum TransitionProgress: Equatable, Sendable {
    case start
    case end
}

struct TransitionResolvedState: Equatable {
    enum Transition: Equatable {
        case interactive(AnyInteractiveTransition)
        case automatic(AnyAutomaticTransition)

        var morphingViews: AnyView {
            switch self {
            case .interactive(let t):
                t.morphingViews
            case .automatic(let t):
                t.morphingViews
            }
        }

        func transitions(morphingViews: MorphingViewsProxy) -> AnyView {
            switch self {
            case .interactive(let t):
                t.transitions(morphingViews: morphingViews)
            case .automatic(let t):
                t.transitions(morphingViews: morphingViews)
            }
        }

        var isComplete: Bool {
            switch self {
            case .interactive(let t):
                t.isComplete
            case .automatic(let t):
                t.progress == .end
            }
        }
    }

    var transition: Transition
    var target: IdentifiedArrayOf<GeneratedPage>

    var sleepingForAnimation = false

    var progress: TransitionProgress {
        switch transition {
        case .interactive(let t):
            t.isComplete ? .end : .start
        case .automatic(let t):
            t.progress
        }
    }
}

enum TransitionStage: Equatable {
    case unresolved(TransitionUnresolvedState)
    case resolved(TransitionResolvedState)
}
