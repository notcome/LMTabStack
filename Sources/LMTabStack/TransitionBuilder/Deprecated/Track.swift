import SwiftUI

private extension EnvironmentValues {
    @Entry
    var timing: TransitionAnimation = .spring
}

public struct Track<Content: View>: View {
    public var timing: TransitionAnimation

    @ViewBuilder
    public var content: Content

    public init(timing: TransitionAnimation, @ViewBuilder content: () -> Content) {
        self.timing = timing
        self.content = content()
    }

    public var body: some View {
        content.environment(\.timing, timing)
    }
}

private struct TransitionScaleModifier: ViewModifier {
    @Environment(\.timing)
    private var timing

    var x: Double?
    var y: Double?

    func body(content: Content) -> some View {
        content.transition(timing: timing) { proxy in
            proxy.scale(x: x, y: y)
        }
    }
}

extension View {
    public func transitionScale(x: Double? = nil, y: Double? = nil) -> some View {
        modifier(TransitionScaleModifier(x: x, y: y))
    }

    public func transitionScale(_ k: CGFloat) -> some View {
        transitionScale(x: k, y: k)
    }
}

private struct TransitionOffsetModifier: ViewModifier {
    @Environment(\.timing)
    private var timing

    var x: Double?
    var y: Double?

    func body(content: Content) -> some View {
        content.transition(timing: timing) { proxy in
            proxy.offset(x: x, y: y)
        }
    }
}

extension View {
    public func transitionOffset(x: Double? = nil, y: Double? = nil) -> some View {
        modifier(TransitionOffsetModifier(x: x, y: y))
    }

    public func transitionOffset(_ d: CGPoint) -> some View {
        transitionOffset(x: d.x, y: d.y)
    }
}

private struct TransitionOpacityModifier: ViewModifier {
    @Environment(\.timing)
    private var timing

    var k: Double

    func body(content: Content) -> some View {
        content.transition(timing: timing) { proxy in
            proxy.opacity(k)
        }
    }
}

extension View {
    public func transitionOpacity(_ k: Double) -> some View {
        modifier(TransitionOpacityModifier(k: k))
    }
}

private struct TransitionBlurRadiusModifier: ViewModifier {
    @Environment(\.timing)
    private var timing

    var r: Double

    func body(content: Content) -> some View {
        content.transition(timing: timing) { proxy in
            proxy.blurRadius(r)
        }
    }
}

extension View {
    public func transitionBlurRadius(_ r: Double) -> some View {
        modifier(TransitionBlurRadiusModifier(r: r))
    }
}
