import ComposableArchitecture
import SwiftUI


struct HostingControllerRepresentable<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(_ content: Content) {
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        return UIHostingController(rootView: content)
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

struct HostingControllerModifier: ViewModifier {

    func body(content: Content) -> some View {
        HostingControllerRepresentable(content)
    }
}


struct NestedModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(HostingControllerModifier())
    }
}

struct PageModifier: ViewModifier {
    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    @Environment(\.pageCoordinator)
    private var pageCoordinator

    func body(content: Content) -> some View {
        let placement = pageCoordinator!.placement

        ctpApplied(content: content)
            .frame(width: placement.frame.width, height: placement.frame.height)
            .offset(x: placement.frame.origin.x, y: placement.frame.origin.y)
            .ignoresSafeArea(.all)
            .environment(\.viewTransitionModel, pageCoordinator!.pageTransitionModel)
    }

    @ViewBuilder
    func ctpApplied(content: Content) -> some View {
        let placement = pageCoordinator!.placement
        let model = pageCoordinator!.pageTransitionModel
        let blurRadius = model.access(\.blurRadius)

        let inner = content
            .safeAreaPadding(placement.safeAreaInsets)
            .frame(width: placement.frame.width, height: placement.frame.height)
            .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                summary.transitionToken = pageCoordinator!.committedTransitionToken
                summary.pageAnchor = pageAnchor
            }
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

extension PageModifier {
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

extension PageModifier {
    struct HybridCTP: ViewModifier {
        var ctp: CommonTransitionProperties?

        func body(content: Content) -> some View {
            CTPAnimationViewControllerRepresentable(props: ctp, content: content)
        }
    }
}
