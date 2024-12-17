import ComposableArchitecture
import SwiftUI

struct TransitionGenerator: View {
    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        if let transition {
            Group(sections: transition.morphingViews) { sections in
                let morphingViews = MorphingViewsProxy.from(sections)
                let transitions = transition.transitions(morphingViews: morphingViews)
                Group(sections: transitions) { sections in
                    let projection = Projection(morphingViews: morphingViews, transition: transition)
                    Color.clear
                        .onChange(of: projection, initial: true) { _, newValue in
                            newValue.update(to: store, sections: sections)
                        }
                }
            }
        }
    }

    var transition: TransitionResolvedState.Transition? {
        guard case .resolved(let state) = store.transitionStage else { return nil }
        return state.transition
    }
}

private struct Projection: Equatable {
    var morphingViewsByPages: [AnyPageID: IdentifiedArrayOf<MorphingViewContent>]
    var transition: TransitionResolvedState.Transition

    init(morphingViews: MorphingViewsProxy, transition: TransitionResolvedState.Transition)  {
        morphingViewsByPages = morphingViews.morphingViewsByPages
        self.transition = transition
    }

    @MainActor
    func update(to store: TabStackStore, sections: SectionCollection) {
        func send(id: AnyPageID, action: PageTransitionFeature.Action, transaction: Transaction? = nil) {
            let action: TabStackFeature.Action = .pages(.element(id: id, action: .transition(.presented(action))))
            if let transaction {
                store.send(action, transaction: transaction)
            } else {
                store.send(action)
            }
        }

        guard transition.isComplete else {
            var updates: [AnyPageID: PageTransitionUpdate] = [:]
            for (pageID, morphingViews) in morphingViewsByPages {
                updates[pageID, default: .init()].morphingViews = morphingViews
            }

            for section in sections {
                for subview in section.content {
                    guard let ref = subview.containerValues.viewRef else { continue }
                    updates[ref.pageID, default: .init()].process(subview: subview)
                }
            }

            var transaction = Transaction()
            transaction.tracksVelocity = transition.isInteractive

            for (id, update) in updates {
                send(id: id, action: .update(update), transaction: transaction)
            }

            store.send(.transitionDidCommit(token: transition.token, animationDuration: nil))
            return
        }


        for (pageID, morphingViews) in morphingViewsByPages {
            send(id: pageID, action: .syncMorphingViews(morphingViews))
        }

        var animationDuration: TimeInterval = 0
        for section in sections {
            guard let timing = section.containerValues.pageTransitionTiming else { continue }
            let transitionAnimation: TransitionAnimation? = transition.isComplete ? timing : nil
            animationDuration = max(animationDuration, transitionAnimation?.animation.duration ?? 0)

            var updates: [AnyPageID: PageTransitionUpdate] = [:]
            for subview in section.content {
                guard let ref = subview.containerValues.viewRef else { continue }
                updates[ref.pageID, default: .init()].process(subview: subview)
            }

            var transaction = Transaction(animation: transitionAnimation?.createSwiftUIAnimation())
            transaction.transitionAnimation = transitionAnimation

            for (id, update) in updates {
                send(id: id, action: .update(update), transaction: transaction)
            }
        }
        store.send(.transitionDidCommit(token: transition.token, animationDuration: animationDuration))
    }
}

private extension PageTransitionUpdate {
    mutating func process(subview: Subview) {
        let ref = subview.containerValues.viewRef!
        let effects = subview.containerValues.transitionEffects

        switch ref {
        case .content:
            contentEffects?.merge(other: effects)
            if contentEffects == nil {
                contentEffects = effects
            }
        case .wrapper:
            wrapperEffects?.merge(other: effects)
            if wrapperEffects == nil {
                wrapperEffects = effects
            }
        case .transitionElement(let id):
            transitionElementEffects[id.elementID, default: .init()].merge(other: effects)
        case .morphingView(let id):
            morphingViewEffects[id.morphingViewID, default: .init()].merge(other: effects)
        }

        if !subview.containerValues.transitionValues.dict.isEmpty {
            transitionValues?.merge(subview.containerValues.transitionValues)
            if transitionValues == nil {
                transitionValues = subview.containerValues.transitionValues
            }
        }
    }
}
