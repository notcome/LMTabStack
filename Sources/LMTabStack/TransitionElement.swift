import SwiftUI

struct TransitionElementSummary: Equatable {
    var transitionToken: Int?
    var pageAnchor: Anchor<CGRect>?
    var elements: [AnyTransitionElementID: Anchor<CGRect>] = [:]

    mutating func merge(_ other: TransitionElementSummary) {
        if let otherToken = other.transitionToken {
            if let currentToken = transitionToken {
                transitionToken = max(currentToken, otherToken)
            } else {
                transitionToken = otherToken
            }
        }
        if let pageAnchor = other.pageAnchor {
            self.pageAnchor = pageAnchor
        }
        for (id, anchor) in other.elements {
            elements[id] = anchor
        }
    }
}

extension TransitionElementSummary: PreferenceKey {
    static var defaultValue: Self { .init() }

    static func reduce(value: inout TransitionElementSummary, nextValue: () -> TransitionElementSummary) {
        value.merge(nextValue())
    }
}

private struct TransitionElementModifier: ViewModifier {
    var id: AnyTransitionElementID

    @Environment(PageStore.self)
    private var store

    @Environment(\.tabStackCoordinator)
    private var tabStackCoordinator

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    func body(content: Content) -> some View {
        let viewRef = ViewRef.transitionElement(.init(pageID: store.id, elementID: id))

        Color.clear
            .overlay {
                switch renderingMode {
                case .pure:
                    content
//                        .modifier(effects ?? .init())
                case .hybrid:
                    TransitionElementHybridBackend(
                        id: id,
                        content: AnyView(content))
                }
            }
            .environment(\.viewTransitionModel, tabStackCoordinator!.viewTransitionModel(for: viewRef))
            .anchorPreference(key: TransitionElementSummary.self, value: .bounds) { anchor in
                var summary = TransitionElementSummary()
                summary.elements[id] = anchor
                return summary
            }
    }
}

private struct TransitionElementHybridBackend: UIViewRepresentable {
    private struct Wrapper: View {
        var id: AnyTransitionElementID
        var content: AnyView

        @TransitionValue(\.blurRadius)
        private var blurRadius

        var body: some View {
            content
                .blur(radius: blurRadius ?? 0)
                .ignoresSafeArea()
        }
    }

    var id: AnyTransitionElementID
    var content: AnyView

    @Environment(\.viewTransitionModel)
    private var viewTransitionModel

    func makeUIView(context: Context) -> UXAnimationView {
        let wrapper = Wrapper(id: id, content: content)
        let hostingView = _UIHostingView(rootView: wrapper)
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
        let hostingView = view.subviews[0] as! _UIHostingView<Wrapper>

        withTransaction(context.transaction) {
            hostingView.rootView.content = content
        }

        if viewTransitionModel.transitionInProgress {
            view.apply(values: viewTransitionModel.access(\.self), transaction: context.transaction)
        } else {
            view.resetAllAnimations()
        }
    }
}

extension View {
    public func transitionElement(id: some Hashable & Sendable) -> some View {
        modifier(TransitionElementModifier(id: AnyTransitionElementID(id)))
    }
}
