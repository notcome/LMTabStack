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

        let ctp = model.transitionInProgress ? model.access(\.commonTransitionProperties) : nil

        switch renderingMode {
        case .pure:
            inner.modifier(PureCTP(ctp: ctp))
        case .hybrid:
            inner.modifier(HybridCTP(ctp: ctp))
        }
    }
}

extension MorphableModifier {
    struct PureCTP: ViewModifier {
        var ctp: CommonTransitionProperties?

        func body(content: Content) -> some View {
            let props = ctp ?? .init()
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
        var ctp: CommonTransitionProperties?

        func body(content: Content) -> some View {
            CTPAnimationViewRepresentable(props: ctp, content: content)
        }
    }
}
