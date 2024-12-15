import SwiftUI

struct TransitionElementSummary: Equatable {
    var pageAnchor: Anchor<CGRect>?
    var elements: [AnyTransitionElementID: Anchor<CGRect>] = [:]

    mutating func merge(_ other: TransitionElementSummary) {
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

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    func body(content: Content) -> some View {
        let effects = store.transition?.transitionElements[id: id]?.effects

        Color.clear
            .overlay {
                switch renderingMode {
                case .pure:
                    content
                        .modifier(effects ?? .init())
                case .hybrid:
                    TransitionElementHybridBackend(
                        id: id,
                        content: AnyView(content),
                        effects: effects)
                }

            }
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

        @Environment(PageStore.self)
        private var store


        var body: some View {
            let blurRadius = store.transition?.transitionElements[id: id]?.effects.blurRadius ?? 0
            content
                .blur(radius: blurRadius)
                .ignoresSafeArea()
        }
    }

    var id: AnyTransitionElementID
    var content: AnyView
    var effects: TransitionEffects?

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

        if let effects {
            view.apply(effects: effects, transaction: context.transaction)
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
