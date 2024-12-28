import ComposableArchitecture
import SwiftUI

struct MorphableModifier: ViewModifier {
    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    @Environment(\.viewTransitionModel)
    private var model

    func body(content: Content) -> some View {
        let blurRadius = model.access(\.blurRadius)
        let inner = content
            .blur(radius: blurRadius ?? 0)

        let props = model.transitionInProgress ? model.access(\.commonTransitionProperties) : nil

        switch renderingMode {
        case .pure:
            inner.modifier(PureCTP(props: props))
        case .hybrid:
            inner.modifier(HybridCTP(props: props))
        }
    }
}

extension MorphableModifier {
    struct PureCTP: ViewModifier {
        var props: CommonTransitionProperties?

        func body(content: Content) -> some View {
            let props = self.props ?? .init()
            content
                .geometryGroup()
                .modifier(_ScaleEffect(scale: props.scale).ignoredByLayout())
                .modifier(_OffsetEffect(offset: props.offset).ignoredByLayout())
                .opacity(props.opacity ?? 1)
        }
    }
}

extension MorphableModifier {
    struct HybridCTP: ViewModifier {
        var props: CommonTransitionProperties?

        func body(content: Content) -> some View {
            CTPAnimationViewRepresentable(props: props, content: content)
        }
    }
}
