import ComposableArchitecture
import SwiftUI

struct TransitionGenerator: View {
    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        if let transition {
            let transitions = transition.transitions
            Group(sections: transitions) { sections in
                let projection = Projection(transition: transition)
                Color.clear
                    .onChange(of: projection, initial: true) { _, newValue in
                        newValue.update(to: store, sections: sections)
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
    var transition: TransitionResolvedState.Transition

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
            for section in sections {
                for subview in section.content {
                    guard let ref = subview.containerValues.viewRef else { continue }

                    let values: TransitionValues = subview.containerValues
                        .transitionValuesBuilder
                        .nonemptyValues
                        .reduce(into: .init()) {
                            $0.merge($1.1)
                        }
                    updates[ref.pageID, default: .init()].process(ref: ref, values: values)
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

        var updates: [TransitionAnimation: [AnyPageID: PageTransitionUpdate]] = [:]

        for section in sections {
            for subview in section.content {
                guard let ref = subview.containerValues.viewRef else { continue }

                for (timing, values) in subview.containerValues.transitionValuesBuilder.nonemptyValues {
                    updates[timing, default: [:]][ref.pageID, default: .init()].process(ref: ref, values: values)
                }
            }
        }
        for (timing, updatesByPage) in updates {
            var transaction = Transaction(animation: timing.createSwiftUIAnimation())
            transaction.transitionAnimation = timing

            for (id, update) in updatesByPage {
                send(id: id, action: .update(update), transaction: transaction)
            }
        }

        let animationDuration: TimeInterval = updates.keys.reduce(into: 0) {
            $0 = max($0, $1.animation.duration)
        }
        store.send(.transitionDidCommit(token: transition.token, animationDuration: animationDuration))
    }
}

private extension PageTransitionUpdate {
    mutating func process(ref: ViewRef, values: TransitionValues) {
        switch ref {
        case .content:
            contentValues?.merge(values)
            if contentValues == nil {
                contentValues = values
            }
        case .wrapper:
            wrapperValues?.merge(values)
            if wrapperValues == nil {
                wrapperValues = values
            }
        case .transitionElement(let id):
            transitionElementValues[id.elementID, default: .init()].merge(values)
        }
    }

}
