import ComposableArchitecture
import SwiftUI

struct CommonTransitionProperties {
    var opacity: Double?
    var offsetX: Double?
    var offsetY: Double?
    var scaleX: Double?
    var scaleY: Double?

    var offset: CGSize {
        .init(width: offsetX ?? 0, height: offsetY ?? 0)
    }

    var scale: CGSize {
        .init(width: scaleX ?? 0, height: scaleY ?? 0)
    }
}

extension TransitionValues {
    var commonTransitionProperties: CommonTransitionProperties {
        .init(
            opacity: opacity,
            offsetX: offsetX,
            offsetY: offsetY,
            scaleX: scaleX,
            scaleY: scaleY)
    }
}

struct MorphableCTPModifier: ViewModifier {
    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    @TransitionValue(\.commonTransitionProperties)
    private var props

    func body(content: Content) -> some View {
        switch renderingMode {
        case .pure:
            content.modifier(Pure(props: props))
        case .hybrid:
            content.modifier(Hybrid(props: props))
        }
    }
}

extension MorphableCTPModifier {
    struct Pure: ViewModifier {
        var props: CommonTransitionProperties

        func body(content: Content) -> some View {
            content
                .geometryGroup()
                .modifier(_ScaleEffect(scale: props.scale).ignoredByLayout())
                .modifier(_OffsetEffect(offset: props.offset).ignoredByLayout())
                .opacity(props.opacity ?? 1)
        }
    }
}

@MainActor
struct PlatformAnimatableView<Content: View> {
    var props: CommonTransitionProperties
    var content: Content
}

extension PlatformAnimatableView: UIViewRepresentable {
    func makeUIView(context: Context) -> UXAnimationView {
        let hostingView = _UIHostingView(rootView: AnyView(content))
        hostingView.backgroundColor = .clear

        let view = UXAnimationView()
        view.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        return view
    }

    func updateUIView(_ view: UXAnimationView, context: Context) {
        let hostingView = view.subviews[0] as! _UIHostingView<AnyView>
        withTransaction(context.transaction) {
            hostingView.rootView = AnyView(content)
        }
    }
}

extension MorphableCTPModifier {
    struct Hybrid: ViewModifier {
        var props: CommonTransitionProperties

        func body(content: Content) -> some View {
            PlatformAnimatableView(props: props, content: content)
        }
    }
}
