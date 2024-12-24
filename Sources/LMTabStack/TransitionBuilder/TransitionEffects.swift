import SwiftUI

public struct TransitionEffectsProxy {
    var effects: TransitionEffects = .init()

    public func scale(x: CGFloat? = nil, y: CGFloat? = nil) -> TransitionEffectsProxy {
        var copy = self
        copy.effects.scaleX = x
        copy.effects.scaleY = y
        return copy
    }

    public func scale(_ k: CGFloat) -> TransitionEffectsProxy {
        scale(x: k, y: k)
    }

    public func offset(x: CGFloat? = nil, y: CGFloat? = nil) -> TransitionEffectsProxy {
        var copy = self
        copy.effects.offsetX = x
        copy.effects.offsetY = y
        return copy
    }

    public func offset(_ d: CGPoint) -> TransitionEffectsProxy {
        offset(x: d.x, y: d.y)
    }

    public func opacity(_ k: CGFloat) -> TransitionEffectsProxy {
        var copy = self
        copy.effects.opacity = k
        return copy
    }

    public func blurRadius(_ r: CGFloat) -> TransitionEffectsProxy {
        var copy = self
        copy.effects.blurRadius = r
        return copy
    }
}

/*
 view
    .transition(timing: .default) { proxy in
        proxy.scale(x: 30, y: 30)
    }
    .transition(timing: .spring) { proxy in
        proxy.offset(x: 300, y: 300)
    }
 */


struct TransitionEffects: Equatable {
    var scaleX: CGFloat?
    var scaleY: CGFloat?
    var offsetX: CGFloat?
    var offsetY: CGFloat?
    var opacity: CGFloat?
    var blurRadius: CGFloat?

    var isEmpty: Bool {
        self == .init()
    }

    mutating func merge(other: TransitionEffects) {
        if let scaleX = other.scaleX {
            self.scaleX = scaleX
        }
        if let scaleY = other.scaleY {
            self.scaleY = scaleY
        }
        if let offsetX = other.offsetX {
            self.offsetX = offsetX
        }
        if let offsetY = other.offsetY {
            self.offsetY = offsetY
        }
        if let opacity = other.opacity {
            self.opacity = opacity
        }
        if let blurRadius = other.blurRadius {
            self.blurRadius = blurRadius
        }
    }
}

extension TransitionEffects: CustomDebugStringConvertible {
    var debugDescription: String {
        var components: [String] = []
        if let scaleX = scaleX { components.append("sx: \(scaleX)") }
        if let scaleY = scaleY { components.append("sy: \(scaleY)") }
        if let offsetX = offsetX { components.append("dx: \(offsetX)") }
        if let offsetY = offsetY { components.append("dy: \(offsetY)") }
        if let opacity = opacity { components.append("alpha: \(opacity)") }
        if let blurRadius = blurRadius { components.append("blurRadius: \(blurRadius)") }
        return "TransitionEffects(\(components.joined(separator: ", ")))"
    }
}

private struct OffsetEffect: GeometryEffect {
    var offset: CGPoint
    
    var animatableData: CGPoint.AnimatableData {
        get { offset.animatableData }
        set { offset.animatableData = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: offset.x, y: offset.y))
    }
}

private struct ScaleEffect: GeometryEffect {
    var scale: CGPoint
    
    var animatableData: CGPoint.AnimatableData {
        get { scale.animatableData }
        set { scale.animatableData = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: centerX, y: centerY)
        transform = transform.scaledBy(x: scale.x, y: scale.y)
        transform = transform.translatedBy(x: -centerX, y: -centerY)

        return ProjectionTransform(transform)
    }
}

extension TransitionEffects: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(ScaleEffect(scale: .init(x: scaleX ?? 1, y: scaleY ?? 1)).ignoredByLayout())
            .modifier(OffsetEffect(offset: .init(x: offsetX ?? 0, y: offsetY ?? 0)).ignoredByLayout())
            .opacity(opacity ?? 1)
            .blur(radius: blurRadius ?? 0)
    }
}
