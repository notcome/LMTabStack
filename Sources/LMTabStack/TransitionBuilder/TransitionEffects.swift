import SwiftUI

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

//extension TransitionEffects: ViewModifier {
//    func body(content: Content) -> some View {
//        content
//            .modifier(ScaleEffect(scale: .init(x: scaleX ?? 1, y: scaleY ?? 1)).ignoredByLayout())
//            .modifier(OffsetEffect(offset: .init(x: offsetX ?? 0, y: offsetY ?? 0)).ignoredByLayout())
//            .opacity(opacity ?? 1)
//            .blur(radius: blurRadius ?? 0)
//    }
//}
