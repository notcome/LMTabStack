import ComposableArchitecture
import SwiftUI

extension Transaction {
    @Entry
    var transitionResolver: TransitionResolver?

    @Entry
    var enableAutomaticTransition: Bool = true
}

public func withTransitionProvider<T: AutomaticTransition>(
    _ provider: @escaping (TransitioningPages) -> T,
    action: () -> Void
) {
    var transaction = Transaction()
    transaction.transitionResolver = .automatic { pages in
        let transition = provider(pages)
        return AnyAutomaticTransition(transition)
    }
    withTransaction(transaction) {
        action()
    }
}

extension ContainerValues {
    @Entry
    var viewRef: ViewRef? = nil

    @Entry
    var pageTransitionTiming: TransitionAnimation? = nil
}

enum ViewRef: Hashable {
    case content(AnyPageID)
    case wrapper(AnyPageID)
    case transitionElement(TransitionElementProxy.ID)
    case morphingView(MorphingViewProxy.ID)

    var pageID: AnyPageID {
        switch self {
        case .content(let pageID), .wrapper(let pageID):
            pageID
        case .transitionElement(let id):
            id.pageID
        case .morphingView(let id):
            id.pageID
        }
    }
}

struct ViewRefView {
    var ref: ViewRef
}

extension ViewRefView: View {
    var body: some View {
        Color.clear
            .containerValue(\.viewRef, ref)
    }
}

extension Transaction {
    @Entry
    var transitionAnimation: TransitionAnimation?
}

struct EmptyTransition: AutomaticTransition {
    var progress: TransitionProgress

    func transitions(morphingViews: MorphingViewsProxy) -> some View {
        EmptyView()
    }
}
