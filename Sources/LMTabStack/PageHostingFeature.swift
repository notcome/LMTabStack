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

        var pageAnchor: Anchor<CGRect>?
        var transitionElements: IdentifiedArrayOf<TransitionElementState> = []

        @ObservationStateIgnored
        @EqualityIgnored
        var _morphingViewContents: IdentifiedArrayOf<MorphingViewContent> = []

        var morphingViewContents: IdentifiedArrayOf<MorphingViewContent> {
            get {
                _$observationRegistrar.access(self, keyPath: \.morphingViewContents)
                return _morphingViewContents
            }
            set {
                _$observationRegistrar.mutate(self, keyPath: \.morphingViewContents, &_morphingViewContents, newValue, { _, _ in false })
            }
        }

        var morphingViewEffects: [AnyMorphingViewID: TransitionEffects] = [:]

        var transitionBehavior: PageTransitionBehavior?
        var transitionEffects: TransitionEffects?
        var wrapperTransitionEffects: TransitionEffects?

        @ObservationStateIgnored
        var transitionReportedStatus: TransitionReportedStatus = .initial
        @ObservationStateIgnored
        var transitionDuration: TimeInterval = 0

        var transitionValues: PageTransitionValues = .init()

        mutating func cleanUpTransition() {
            transitionBehavior = nil
            transitionEffects = nil
            wrapperTransitionEffects = nil

            transitionReportedStatus = .initial
            transitionDuration = 0

            for id in transitionElements.ids {
                transitionElements[id: id]?.transitionEffects = nil
            }

            transitionValues.reset()

            morphingViewContents = []
            morphingViewEffects = [:]
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
        case syncWrapperTransitionEffects(TransitionEffects)
        case syncTransitionElements(TransitionElementSummary)
        case syncTransitionValues(PageTransitionValues)
        case syncTransitionElementEffects(AnyTransitionElementID, TransitionEffects)

        case syncMorphingViewContents(IdentifiedArrayOf<MorphingViewContent>)
        case syncMorphingViewEffects(AnyMorphingViewID, TransitionEffects)

        case transitionDidStart
        case transitionDidEnd(TimeInterval)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .syncTransitionEffects(let effects):
            state.transitionEffects!.merge(other: effects)
        case .syncWrapperTransitionEffects(let effects):
            state.wrapperTransitionEffects!.merge(other: effects)
        case let .syncTransitionElementEffects(id, effects):
            if state.transitionElements[id: id]!.transitionEffects == nil {
                state.transitionElements[id: id]!.transitionEffects = effects
            } else {
                state.transitionElements[id: id]!.transitionEffects!.merge(other: effects)
            }
        case .syncTransitionValues(let newValues):
            state.transitionValues.merge(newValues)

        case .syncTransitionElements(let summary):
            guard summary.pageAnchor != nil else { break }
            state.pageAnchor = summary.pageAnchor
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

            print("transition elements merged", state.transitionElements.ids.map(\.base))

        case .syncMorphingViewContents(let contents):
            assert(state.transitionBehavior != nil)
            for content in contents {
                if state.morphingViewContents[id: content.id] == nil {
                    state.morphingViewContents.append(content)
                }
            }

        case let .syncMorphingViewEffects(id, effects):
            state.morphingViewEffects[id, default: .init()].merge(other: effects)

        case .transitionDidStart:
            state.transitionReportedStatus = .didStart
        case .transitionDidEnd(let duration):
            state.transitionReportedStatus = .didEnd
            state.transitionDuration = max(state.transitionDuration, duration)
        }
        return .none
    }
}

typealias PageHostingStore = StoreOf<PageHostingFeature>
