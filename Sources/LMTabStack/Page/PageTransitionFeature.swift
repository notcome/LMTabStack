import ComposableArchitecture
import SwiftUI

public enum PageTransitionBehavior: Equatable {
    case appear(PagePlacement)
    case disappear(PagePlacement)
    case change(PagePlacement, PagePlacement)

    public var isAppearing: Bool {
        guard case .appear = self else { return false }
        return true
    }

    public var isDisappearing: Bool {
        guard case .disappear = self else { return false }
        return true
    }
}

@ObservableState
struct TransitionElementTransitionState: Identifiable, Equatable {
    var id: AnyTransitionElementID
    var frame: CGRect
}

@Reducer
struct PageTransitionFeature {
    @ObservableState
    struct State: Identifiable, Equatable {
        var id: AnyPageID
        var frame: CGRect

        var transitionToken: Int?

        var behavior: PageTransitionBehavior
        var transitionElements: IdentifiedArrayOf<TransitionElementTransitionState> = []

        init?(pageState: PageFeature.State, behavior: PageTransitionBehavior) {
            guard let mountedLayout = pageState.mountedLayout else { return nil }
            id = pageState.id
            frame = mountedLayout.pageFrame
            self.behavior = behavior

            for (id, frame) in mountedLayout.transitionElements {
                transitionElements.append(.init(id: id, frame: frame))
            }
        }
    }
}
