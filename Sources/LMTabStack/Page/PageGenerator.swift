import ComposableArchitecture
import SwiftUI

struct PageGenerator: View {
    var viewContent: ViewContent

    @Environment(\.tabStackLayout)
    private var tabStackLayout

    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        GeometryReader { withKeyboardProxy in
            GeometryReader { withoutKeyboardProxy in
                let layoutOutput = computeLayout(
                    withKeyboardProxy: withKeyboardProxy,
                    withoutKeyboardProxy: withoutKeyboardProxy)
                let layoutPages = layoutOutput.pages
                let pages = viewContent.pages.map { page in
                    let placement = layoutPages[id: page.id]?.placement
                    return GeneratedPage(id: page.id, content: page.content, placement: placement)
                }

                Color.clear
                    .onChangeWithTransaction(of: layoutPages) { layout, tx in
                        var resolver: TransitionResolver?
                        if let explicitResolver = tx.transitionResolver {
                            resolver = explicitResolver
                        } else if tx.enableAutomaticTransition {
                            resolver = .automatic { pages in
                                let resolver = viewContent.automaticTransitionResolver
                                guard let t = resolver.resolve(transitioningPages: pages) else {
                                    return .init(EmptyTransition(progress: .start))
                                }
                                return t
                            }
                        }
                        store.send(.update(.init(uniqueElements: pages), resolver))
                    }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    func computeLayout(withKeyboardProxy: GeometryProxy, withoutKeyboardProxy: GeometryProxy) -> LayoutOutput {
        let layoutInput = LayoutInput.from(viewContent)
        let layoutProxy = TabStackLayoutProxy.from(layoutInput)
        let context = TabStackLayoutContext(
            bounds: withKeyboardProxy.boundsWithoutSafeAreaInsets,
            safeAreaInsets: withoutKeyboardProxy.safeAreaInsets,
            keyboardSafeAreaInsets: withKeyboardProxy.safeAreaInsets)

        tabStackLayout.placePages(in: context, layout: layoutProxy)
        return .from(layoutProxy)
    }
}
