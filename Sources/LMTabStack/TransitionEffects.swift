import SwiftUI

struct TransitionEffects: Equatable {
    var scaleX: CGFloat?
    var scaleY: CGFloat?
    var offsetX: CGFloat?
    var offsetY: CGFloat?
    var opacity: CGFloat?
    var blurRadius: CGFloat?

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
