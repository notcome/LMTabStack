import ComposableArchitecture
import SwiftUI

@MainActor
@propertyWrapper
public struct TransitionInteraction<Transition: InteractiveTransition>: DynamicProperty {
    @Environment(TabStackStore.self)
    private var store

    public init() {}

    public var wrappedValue: Transition? {
        guard case .resolved(let resolved) = store.transitionStage,
              case .interactive(let untyped) = resolved.transition,
              let transition = untyped.base as? Transition
        else {
            return nil
        }
        return transition
    }

    public var projectedValue: Self {
        get {
            self
        }
        set {
            self = newValue
        }
    }

    public func startInteractiveTransition(
        updateState: () -> Void,
        provideTransition: @escaping (TransitioningPages) -> Transition
    ) {
        var transaction = Transaction()
        transaction.transitionResolver = .interactive { pages in
            .init(provideTransition(pages))
        }
        withTransaction(transaction, updateState)
    }

    public func updateTransition(body: @escaping (inout Transition) -> Void) {
        guard wrappedValue != nil else {
            assertionFailure("No interactive transition of type \(Transition.self) is active.")
            return
        }
        let transaction = Transaction()
        store.send(.updateInteractiveTransition {
            $0.modify(as: Transition.self, body: body)
        }, transaction: transaction)
    }

    public func completeTransition(updateState: () -> Void, updateTransition body: @escaping (inout Transition) -> Void) {
        // Any state update during a transition will be applied immediately post transition.
        updateState()
        updateTransition { t in
            body(&t)
            assert(t.isComplete)
        }
    }
}
