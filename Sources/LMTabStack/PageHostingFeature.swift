import ComposableArchitecture
import SwiftUI

enum TransitionReportedStatus: Hashable {
    case initial
    case didStart
    case didEnd
}

struct TransitionElementState: Equatable, Identifiable {
    var id: AnyTransitionElementID
    var transitionEffects: TransitionEffects?
    @ObservationStateIgnored
    var anchor: Anchor<CGRect>
}

@Reducer
struct PageHostingFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: AnyPageID
        var placement: PagePlacement
        var hidden: Bool

        @ObservationStateIgnored
        var transitionElementsMounted: Bool = false
        var transitionElements: IdentifiedArrayOf<TransitionElementState> = []

        var transitionBehavior: PageTransitionBehavior?
        var transitionEffects: TransitionEffects?
        @ObservationStateIgnored
        var transitionReportedStatus: TransitionReportedStatus = .initial

        var transitionValues: PageTransitionValues = .init()

        mutating func cleanUpTransition() {
            transitionBehavior = nil
            transitionEffects = nil
            transitionReportedStatus = .initial

            for id in transitionElements.ids {
                transitionElements[id: id]?.transitionEffects = nil
            }

            transitionValues.reset()
        }

        func placement(for transitionProgress: TransitionProgress?) -> PagePlacement {
            guard let transitionBehavior,
                  let transitionProgress
            else { return placement }

            switch transitionBehavior {
            case .appear(let pagePlacement), .disappear(let pagePlacement):
                return pagePlacement
            case .identity(let start, let end):
                return transitionProgress == .start ? start : end
            }
        }

        func opacity(for transitionProgress: TransitionProgress?) -> Double {
            guard transitionProgress == nil || transitionBehavior == nil else {
                return 1
            }
            return hidden ? 0 : 1
        }
    }

    enum Action {
        case syncTransitionEffects(TransitionEffects)
        case syncTransitionElements(TransitionElementSummary)
        case syncTransitionValues(PageTransitionValues)
        case syncTransitionElementEffects(AnyTransitionElementID, TransitionEffects)
        case transitionDidStart
        case transitionDidEnd
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .syncTransitionEffects(let effects):
            state.transitionEffects!.merge(other: effects)
        case let .syncTransitionElementEffects(id, effects):
            if state.transitionElements[id: id]!.transitionEffects == nil {
                state.transitionElements[id: id]!.transitionEffects = effects
            } else {
                state.transitionElements[id: id]!.transitionEffects!.merge(other: effects)
            }
        case .syncTransitionValues(let newValues):
            state.transitionValues.merge(newValues)

        case .syncTransitionElements(let summary):
            state.transitionElementsMounted = true
            for (id, anchor) in summary.elements {
                if state.transitionElements[id: id] != nil {
                    state.transitionElements[id: id]!.anchor = anchor
                } else {
                    state.transitionElements[id: id] = .init(id: id, anchor: anchor)
                }
            }
            for id in state.transitionElements.ids where summary.elements[id] == nil {
                state.transitionElements[id: id] = nil
            }
        case .transitionDidStart:
            updateIfNeeded(&state.transitionReportedStatus, to: .didStart)
        case .transitionDidEnd:
            updateIfNeeded(&state.transitionReportedStatus, to: .didEnd)
        }
        return .none
    }
}

typealias PageHostingStore = StoreOf<PageHostingFeature>
