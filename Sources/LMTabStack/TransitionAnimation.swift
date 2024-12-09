import SwiftUI

protocol TransitionAnimationProtocol {
    var duration: Double { get }

    func createCAAnimation() -> CABasicAnimation
    func createSwiftUIAnimation() -> Animation
}

enum TimingCurve: Hashable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case custom(Double, Double, Double, Double)

    var timingFunction: CAMediaTimingFunction {
        switch self {
        case .linear:
            return .init(name: .linear)
        case .easeIn:
            return .init(name: .easeIn)
        case .easeOut:
            return .init(name: .easeOut)
        case .easeInOut:
            return .init(name: .easeInEaseOut)
        case let .custom(p1x, p1y, p2x, p2y):
            let c1x = Float(p1x)
            let c1y = Float(p1y)
            let c2x = Float(p2x)
            let c2y = Float(p2y)
            return CAMediaTimingFunction(controlPoints: c1x, c1y, c2x, c2y)
        }
    }
}

struct TimingCurveTransitionAnimation: TransitionAnimationProtocol {
    var timingCurve: TimingCurve
    var duration: Double

    func createCAAnimation() -> CABasicAnimation {
        let timingFunction = timingCurve.timingFunction
        let animation = CABasicAnimation()
        animation.timingFunction = timingFunction
        animation.duration = duration
        return animation
    }

    func createSwiftUIAnimation() -> Animation {
        switch timingCurve {
        case .linear:
            .linear(duration: duration)
        case .easeIn:
            .easeIn(duration: duration)
        case .easeOut:
            .easeOut(duration: duration)
        case .easeInOut:
            .easeInOut(duration: duration)
        case let .custom(p1x, p1y, p2x, p2y):
            .timingCurve(p1x, p1y, p2x, p2y, duration: duration)
        }
    }
}

enum SpringTiming {
    case simple(duration: Double, bounce: Double)

    func createCAAnimation() -> CASpringAnimation {
        switch self {
        case let .simple(duration, bounce):
            CASpringAnimation(perceptualDuration: duration, bounce: bounce)
        }
    }
}

struct SpringTransitionAnimation: TransitionAnimationProtocol {
    var timing: SpringTiming
    var duration: Double

    init(timing: SpringTiming) {
        self.timing = timing
        self.duration = timing.createCAAnimation().duration
    }

    func createCAAnimation() -> CABasicAnimation {
        timing.createCAAnimation()
    }

    func createSwiftUIAnimation() -> Animation {
        let spring: Spring
        switch timing {
        case .simple(let duration, let bounce):
            spring = .init(duration: duration, bounce: bounce)
        }
        return .spring(spring)
    }
}

/// A limited set of animations.
///
/// They need to be correctly rendered in both SwiftUI and Core Animation.
public struct TransitionAnimation {
    var animation: any TransitionAnimationProtocol

    public func createCAAnimation() -> CABasicAnimation {
        animation.createCAAnimation()
    }

    public func createSwiftUIAnimation() -> Animation {
        animation.createSwiftUIAnimation()
    }

    public static func linear(duration: Double) -> Self {
        .init(animation: TimingCurveTransitionAnimation(timingCurve: .linear, duration: duration))
    }

    public static var linear: Self {
        .linear(duration: 0.35)
    }

    public static func easeIn(duration: Double) -> Self {
        .init(animation: TimingCurveTransitionAnimation(timingCurve: .easeIn, duration: duration))
    }

    public static var easeIn: Self {
        .easeIn(duration: 0.35)
    }

    public static func easeOut(duration: Double) -> Self {
        .init(animation: TimingCurveTransitionAnimation(timingCurve: .easeOut, duration: duration))
    }

    public static var easeOut: Self {
        .easeOut(duration: 0.35)
    }

    public static func easeInOut(duration: Double) -> Self {
        .init(animation: TimingCurveTransitionAnimation(timingCurve: .easeInOut, duration: duration))
    }

    public static var easeInOut: Self {
        .easeInOut(duration: 0.35)
    }

    public static func custom(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double, duration: Double = 0.35) -> Self {
        .init(animation: TimingCurveTransitionAnimation(timingCurve: .custom(p1x, p1y, p2x, p2y), duration: duration))
    }

    public static func spring(duration: TimeInterval, bounce: Double) -> Self {
        .init(animation: SpringTransitionAnimation(timing: .simple(duration: duration, bounce: bounce)))
    }

    public static var spring: Self {
        .spring(duration: 0.5, bounce: 0)
    }
}
