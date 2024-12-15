import ComposableArchitecture
import SwiftUI

struct PageMountedLayout: Equatable {
    var pageFrame: CGRect
    var transitionElements: [AnyTransitionElementID: CGRect]
}

@Reducer
struct PageFeature {
    @ObservableState
    struct State: Identifiable, Equatable {
        var id: AnyPageID

        @ObservationStateIgnored
        @EqualityIgnored
        var content: AnyView

        var placement: PagePlacement
        var hidden: Bool = false

        init(id: AnyPageID, content: AnyView, placement: PagePlacement) {
            self.id = id
            _content = .init(wrappedValue: content)
            self.placement = placement
        }


        // We want to be able to observe hasLoaded while ignoring subsequent changes to mountedLayout.
        // Therefore, hasLoaded is not a computed property, but a stored property with a private setter.
        //
        private(set) var hasLoaded: Bool = false
        @ObservationStateIgnored
        private(set) var mountedLayout: PageMountedLayout?

        mutating func merge(mountedLayout: PageMountedLayout) {
            self.mountedLayout = mountedLayout
            if !hasLoaded {
                hasLoaded = true
            }
        }

        var transitionBehavior: PageTransitionBehavior?
        @Presents
        var transition: PageTransitionFeature.State?
    }

    enum DelegateAction {
        case pageDidLoad
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(DelegateAction)
        case transition(PresentationAction<PageTransitionFeature.Action>)

        case syncMountedLayout(PageMountedLayout)
    }

    var body: some Reducer<State, Action> {
        CombineReducers {
            BindingReducer()
            Reduce(reduceSelf(state:action:))
        }
        .ifLet(\.$transition, action: \.transition) {
            PageTransitionFeature()
        }
        .onChange(of: \.hasLoaded) { _, hasLoaded in
            Reduce { _, _ in
                return if hasLoaded {
                    .send(.delegate(.pageDidLoad))
                } else {
                    .none
                }
            }
        }
    }

    private func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .syncMountedLayout(let mountedLayout):
            state.merge(mountedLayout: mountedLayout)
        default:
            break
        }
        return .none
    }
}

extension PageFeature.State {
    var resolvedPlacement: PagePlacement {
        guard let transitionBehavior else { return placement }
        switch transitionBehavior {
        case .appear(let x), .disappear(let x):
            return x
        case .change(let old, _):
            return old
        }
    }

    var resolvedOpacity: Double {
        hidden || !hasLoaded ? 0 : 1
    }
}

typealias PageStore = StoreOf<PageFeature>
