import ComposableArchitecture
import SwiftUI

@propertyWrapper
public struct InteractiveTransition<Definition: TransitionDefinition> {
    public init() {}

    public var wrappedValue: Definition? {
        fatalError()
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
        provideTransition: (IdentifiedArrayOf<PageProxy>) -> Definition
    ) {

    }

    public func update(body: (inout Definition) -> Void) {

    }
}
