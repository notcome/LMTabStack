import ComposableArchitecture
import SwiftUI

@MainActor
protocol ViewTransitionModel {
    var transitionInProgress: Bool { get }
    func access<T>(_ keyPath: KeyPath<TransitionValues, T>) -> T
}

struct EmptyViewTransitionModel: ViewTransitionModel {
    var transitionInProgress: Bool { false }

    func access<T>(_ keyPath: KeyPath<TransitionValues, T>) -> T {
        TransitionValues()[keyPath: keyPath]
    }
}

extension EnvironmentValues {
    @Entry
    var viewTransitionModel: any ViewTransitionModel = EmptyViewTransitionModel()
}

@MainActor
@propertyWrapper
public struct TransitionValue<Value>: DynamicProperty {
    @Environment(\.viewTransitionModel.self)
    private var model

    private var keyPath: KeyPath<TransitionValues, Value>

    public init(_ keyPath: KeyPath<TransitionValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        model.access(keyPath)
    }

    public struct TransitionMetadata {
        public var transitionInProgress: Bool
    }

    public var projectedValue: TransitionMetadata {
        .init(transitionInProgress: model.transitionInProgress)
    }
}

@MainActor
@propertyWrapper
public struct TransitionInProgress: DynamicProperty {
    @Environment(\.viewTransitionModel.self)
    private var model

    public init() {}

    public var wrappedValue: Bool {
        model.transitionInProgress
    }
}
