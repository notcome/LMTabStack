import ComposableArchitecture
import SwiftUI

typealias TransitionValuesStore = Store<TransitionValues, Never>

@MainActor
private let globalDummy: TransitionValuesStore = Store(initialState: .init()) {
    EmptyReducer()
}

@MainActor
func scopeToTransitionValuesStore<S: ObservableState>(
    store: Store<S, some CasePathable>,
    state: KeyPath<S, TransitionValues?>
) -> TransitionValuesStore {
    if let childStore = store.scope(state: state, action: \.never) as TransitionValuesStore? {
        return childStore
    }
    return globalDummy
}

@MainActor
@propertyWrapper
public struct TransitionValueReader<Value>: DynamicProperty {
    @Environment(TransitionValuesStore.self)
    private var store

    private var keyPath: KeyPath<TransitionValues, Value>

    public var wrappedValue: Value {
        store.state[keyPath: keyPath]
    }

    public init(_ keyPath: KeyPath<TransitionValues, Value>) {
        self.keyPath = keyPath
    }
}
