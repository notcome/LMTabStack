import ComposableArchitecture
import SwiftUI

@MainActor
final class BoxedTransitionProvider<Definition: TransitionDefinition>: TransitionProvider {
    weak var store: TabStackStore?
    var provideTransition: (IdentifiedArrayOf<PageProxy>) -> Definition
    var definition: Definition?
    var cachedUpdate: ((inout Definition) -> Void)?

    init(store: TabStackStore, provideTransition: @escaping (IdentifiedArrayOf<PageProxy>) -> Definition) {
        self.store = store
        self.provideTransition = provideTransition
    }

    func transitions(for transitioningPages: IdentifiedCollections.IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> any TransitionDefinition {
        if let definition {
            return definition
        }

        definition = provideTransition(transitioningPages)

        if let cachedUpdate {
            cachedUpdate(&definition!)
            self.cachedUpdate = nil
        }
        return definition!
    }

    func updateTransition(body: @escaping (inout Definition) -> Void) {
        if definition == nil {
            cachedUpdate = body
            return
        }
        body(&definition!)
        store?.send(.refreshTransition)
    }
}

@MainActor
@propertyWrapper
public struct InteractiveTransition<Definition: TransitionDefinition>: DynamicProperty {
    @Environment(TabStackStore.self)
    private var store

    public init() {}

    public var wrappedValue: Definition? {
        guard let box = store.transitionProvider as? BoxedTransitionProvider<Definition>
        else {
            print("Unexpected transition provider", type(of: store.transitionProvider))
            return nil
        }
        return box.definition
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
        provideTransition: @escaping (IdentifiedArrayOf<PageProxy>) -> Definition
    ) {
        let box = BoxedTransitionProvider(store: store, provideTransition: provideTransition)
        var transaction = Transaction()
        transaction.interactiveTransitionProgress = .start
        transaction.transitionProvider = box
        transaction.tracksVelocity = true
        withTransaction(transaction, updateState)
    }

    public func updateTransition(body: @escaping (inout Definition) -> Void) {
        let box = store.transitionProvider as! BoxedTransitionProvider<Definition>
        box.updateTransition(body: body)
    }

    public func completeTransition(body: @escaping (inout Definition) -> Void) {
        let box = store.transitionProvider as! BoxedTransitionProvider<Definition>
        body(&box.definition!)
        box.store!.send(.completeInteractiveTransition)
    }

    public func cancelTransition(updateState: () -> Void, updateTransition: @escaping (inout Definition) -> Void) {
        let box = store.transitionProvider as! BoxedTransitionProvider<Definition>
        updateTransition(&box.definition!)
        var transaction = Transaction()
        transaction.interactiveTransitionProgress = .end
        transaction.transitionProvider = box
        withTransaction(transaction, updateState)
    }
}
