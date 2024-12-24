import SwiftUI

struct TransitionValuesBuilder {
    private var dict: [TransitionAnimation: TransitionValues] = [:]

    subscript(animation: TransitionAnimation) -> TransitionValues {
        get {
            dict[animation, default: .init()]
        }
        set {
            dict[animation, default: .init()].merge(newValue)
        }
    }

    var nonemptyValues: some Sequence<(TransitionAnimation, TransitionValues)> {
        dict.compactMap { (key, value) in
            guard !value.isEmpty else { return nil }
            return (key, value)
        }
    }
}

extension ContainerValues {
    @Entry
    var transitionValuesBuilder: TransitionValuesBuilder = .init()
}

public struct TransitionValuesProxy {
    var values: TransitionValues = .init()

    private func writeOnCopy(body: (inout Self) -> Void) -> Self {
        var copy = self
        body(&copy)
        return copy
    }

    public func transition<Value>(_ keyPath: WritableKeyPath<TransitionValues, Value>, _ value: Value) -> Self {
        writeOnCopy { $0.values[keyPath: keyPath] = value }
    }

    public func scale(x: Double? = nil, y: Double? = nil) -> Self {
        writeOnCopy {
            $0.values.scaleX = x
            $0.values.scaleY = y
        }
    }

    public func scale(_ k: Double) -> Self {
        scale(x: k, y: k)
    }

    public func offset(x: Double? = nil, y: Double? = nil) -> Self {
        writeOnCopy {
            $0.values.offsetX = x
            $0.values.offsetY = y
        }
    }

    public func opacity(_ k: CGFloat) -> Self {
        transition(\.opacity, k)
    }

    public func blurRadius(_ r: CGFloat) -> Self {
        transition(\.blurRadius, r)
    }
}

extension View {
    public func transition(timing: TransitionAnimation, body: (TransitionValuesProxy) -> TransitionValuesProxy) -> some View {
        let values = body(.init()).values
        return containerValue(\.transitionValuesBuilder[timing], values)
    }
}
