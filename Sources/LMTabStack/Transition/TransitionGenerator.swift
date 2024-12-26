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
        guard transition.isComplete else {
            var updates: [ViewRef: TransitionValues] = [:]
            for section in sections {
                for subview in section.content {
                    guard let ref = subview.containerValues.viewRef else { continue }

                    let values: TransitionValues = subview.containerValues
                        .transitionValuesBuilder
                        .nonemptyValues
                        .reduce(into: .init()) {
                            $0.merge($1.1)
                        }
                    updates[ref, default: .init()].merge(values)
                }
            }

            var transaction = Transaction()
            transaction.tracksVelocity = transition.isInteractive

            store.send(.updateAllTransitionValues(updates), transaction: transaction)
            store.send(.transitionDidCommit(token: transition.token, animationDuration: nil))
            return
        }

        var updatesByTiming: [TransitionAnimation: [ViewRef: TransitionValues]] = [:]

        for section in sections {
            for subview in section.content {
                guard let ref = subview.containerValues.viewRef else { continue }

                for (timing, values) in subview.containerValues.transitionValuesBuilder.nonemptyValues {
                    updatesByTiming[timing, default: [:]][ref, default: .init()].merge(values)
                }
            }
        }
        for (timing, updates) in updatesByTiming {
            var transaction = Transaction(animation: timing.createSwiftUIAnimation())
            transaction.transitionAnimation = timing
            store.send(.updateAllTransitionValues(updates), transaction: transaction)
        }

        let animationDuration: TimeInterval = updatesByTiming.keys.reduce(into: 0) {
            $0 = max($0, $1.animation.duration)
        }
        store.send(.transitionDidCommit(token: transition.token, animationDuration: animationDuration))
    }
}
