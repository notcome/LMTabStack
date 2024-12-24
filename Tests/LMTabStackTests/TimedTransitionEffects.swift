import Testing

@testable
import LMTabStack

struct TransitionEffectsBuilder {
    private var storage: [TransitionAnimation : TransitionEffects] = [:]
    var current: TransitionEffects = .init()

    var animation: TransitionAnimation! {
        get { nil }
        set {
            storage[newValue, default: .init()].merge(other: current)
            current = .init()
        }
    }

    func finalize() -> [TransitionAnimation: TransitionEffects] {
        var dict = storage
        precondition(current.isEmpty)
        for (key, value) in dict where value.isEmpty {
            dict[key] = nil
        }
        return dict
    }
}

@Test
func foo() {
    var effects = TransitionEffectsBuilder()
    effects.current.offsetX = 0
    effects.current.offsetY = 0
    effects.animation = .easeIn
    effects.animation = .easeOut
    let results = effects.finalize()
    for result in results.values {
        #expect(!result.isEmpty)
    }
    #expect(1 + 1 == 2)
}
