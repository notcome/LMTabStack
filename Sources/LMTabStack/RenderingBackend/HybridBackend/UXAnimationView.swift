import SwiftUI
import UIKit

struct VelocityTracker {
    private var samples: [(CFTimeInterval, Double)] = []

    mutating func addSample(_ value: Double) {
        let pair = (CACurrentMediaTime(), value)
        switch samples.count {
        case 2:
            samples[0] = samples[1]
            samples[1] = pair
        case 0, 1:
            samples.append(pair)
        default:
            fatalError()
        }
    }

    var absoluteVelocity: Double {
        switch samples.count {
        case 2:
            let (t1, x1) = samples[0]
            let (t2, x2) = samples[1]
            return (x2 - x1) / (t2 - t1)
        default:
            return 0
        }
    }
}

final class UXAnimationView: UIView {
    private(set) var keyPathStates: [String: KeyPathState] = [:]
    private(set) var velocityTrackers: [String: VelocityTracker] = [:]
}

extension UXAnimationView {
    enum KeyPathState {
        case constant(Double)
        case animating(Double, Double)
    }

    func apply(effects: TransitionEffects, transaction: Transaction) {
        if let opacity = effects.opacity {
            update(keyPath: "opacity", to: opacity, transaction: transaction)
        }
        if let scaleX = effects.scaleX {
            update(keyPath: "transform.scale.x", to: scaleX, transaction: transaction)
        }
        if let scaleY = effects.scaleY {
            update(keyPath: "transform.scale.y", to: scaleY, transaction: transaction)
        }
        if let offsetX = effects.offsetX {
            update(keyPath: "transform.translation.x", to: offsetX, transaction: transaction)
        }
        if let offsetY = effects.offsetY {
            update(keyPath: "transform.translation.y", to: offsetY, transaction: transaction)
        }
    }

    func resetAllAnimations() {
        layer.removeAllAnimations()
        keyPathStates = [:]
        velocityTrackers = [:]
    }
}

private extension UXAnimationView {
    func addConstantAnimation(keyPath: String, value: Double, transaction: Transaction) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = value
        animation.toValue = value
        animation.speed = 0
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .constant(value)

        if transaction.tracksVelocity {
            velocityTrackers[keyPath, default: .init()].addSample(value)
        }
    }

    func addAnimation(_ animation: CABasicAnimation, keyPath: String, from oldValue: Double, to newValue: Double) {
        animation.preferredFrameRateRange = .init(minimum: 60, maximum: 120, preferred: 120)
        animation.fromValue = oldValue
        animation.toValue = newValue
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .animating(oldValue, newValue)
    }

    func update(keyPath: String, to newValue: Double, transaction: Transaction) {
        let transitionAnimation = transaction.transitionAnimation

        guard let state = keyPathStates[keyPath] else {
            assert(transitionAnimation == nil)
            addConstantAnimation(keyPath: keyPath, value: newValue, transaction: transaction)
            return
        }

        switch state {
        case let .constant(oldValue):
            guard oldValue != newValue else { return }
            guard let transitionAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue, transaction: transaction)
                return
            }
            let animation: CABasicAnimation
            if let absoluteVelocity = velocityTrackers[keyPath]?.absoluteVelocity, absoluteVelocity != 0 {
                let relativeVelocity = absoluteVelocity / (newValue - oldValue)
                animation = transitionAnimation.animation.createCAAnimation(initialVelocity: relativeVelocity)
            } else {
                animation = transitionAnimation.animation.createCAAnimation()
            }
            addAnimation(animation, keyPath: keyPath, from: oldValue, to: newValue)

        case let .animating(oldValue, currentNewValue):
            guard let transitionAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue, transaction: transaction)
                return
            }
            guard currentNewValue != newValue else { return }
            assertionFailure()
            addAnimation(transitionAnimation.createCAAnimation(), keyPath: keyPath, from: oldValue, to: newValue)
        }
    }
}
