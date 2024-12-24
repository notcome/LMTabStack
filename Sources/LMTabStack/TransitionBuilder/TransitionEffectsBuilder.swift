import SwiftUI

struct TransitionEffectsBuilder {
    private var dict: [TransitionAnimation: TransitionEffects] = [:]

    subscript(animation: TransitionAnimation) -> TransitionEffects {
        get {
            dict[animation, default: .init()]
        }
        set {
            dict[animation, default: .init()].merge(other: newValue)
        }
    }

    var nonemptyEffects: some Sequence<(TransitionAnimation, TransitionEffects)> {
        dict.compactMap { (key, value) in
            guard !value.isEmpty else { return nil }
            return (key, value)
        }
    }
}

extension ContainerValues {
    @Entry
    var transitionEffectsBuilder: TransitionEffectsBuilder = .init()
}


extension View {
    public func transition(timing: TransitionAnimation, body: (TransitionEffectsProxy) -> TransitionEffectsProxy) -> some View {
        let effects = body(.init()).effects
        return containerValue(\.transitionEffectsBuilder[timing], effects)
    }
}
