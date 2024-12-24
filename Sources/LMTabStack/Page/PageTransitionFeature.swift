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
    var values = TransitionValues()
}

@ObservableState
struct MorphingViewState: Identifiable, Equatable {
    var id: AnyMorphingViewID

    @ObservationStateIgnored
    @EqualityIgnored
    var content: AnyView

    var zIndex: Double = 0
    var values = TransitionValues()
}

struct PageTransitionUpdate: Equatable {
    var morphingViews: IdentifiedArrayOf<MorphingViewContent> = []

    var contentValues: TransitionValues?
    var wrapperValues: TransitionValues?

    var transitionElementValues: [AnyTransitionElementID: TransitionValues] = [:]
    var morphingViewValues: [AnyMorphingViewID: TransitionValues] = [:]
}

@Reducer
struct PageTransitionFeature {
    @ObservableState
    struct State: Identifiable, Equatable {
        var id: AnyPageID
        var frame: CGRect

        var transitionToken: Int?

        var behavior: PageTransitionBehavior
        var contentValues = TransitionValues()
        var wrapperValues = TransitionValues()

        var transitionElements: IdentifiedArrayOf<TransitionElementTransitionState> = []
        var morphingViews: IdentifiedArrayOf<MorphingViewState> = []

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

    enum Action {
        case syncMorphingViews(IdentifiedArrayOf<MorphingViewContent>)
        case update(PageTransitionUpdate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .syncMorphingViews(let views):
            for view in views {
                let id = view.id
                let zIndex = view.zIndex ?? 0
                if state.morphingViews[id: id] != nil {
                    updateIfNeeded(&state.morphingViews[id: id]!.zIndex, to: zIndex)
                } else {
                    state.morphingViews.append(.init(id: id, content: view.content, zIndex: zIndex))
                }
            }
        case .update(let update):
            state.apply(update: update)
        }
        return .none
    }
}

extension PageTransitionFeature.State {
    mutating func apply(update: PageTransitionUpdate) {
        for morphingView in update.morphingViews {
            let id = morphingView.id
            let zIndex = morphingView.zIndex ?? 0
            if morphingViews[id: id] != nil {
                updateIfNeeded(&morphingViews[id: id]!.zIndex, to: zIndex)
            } else {
                morphingViews.append(.init(id: id, content: morphingView.content, zIndex: zIndex))
            }
        }

        if let values = update.contentValues {
            contentValues.merge(values)
        }
        if let values = update.wrapperValues {
            wrapperValues.merge(values)
        }
        for (id, values) in update.transitionElementValues {
            transitionElements[id: id]!.values.merge(values)
        }
        for (id, values) in update.morphingViewValues {
            morphingViews[id: id]!.values.merge(values)
        }
    }
}
