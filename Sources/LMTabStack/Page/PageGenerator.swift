import ComposableArchitecture
import SwiftUI

struct PageGenerator: View {
    var viewContent: ViewContent

    @Environment(\.tabStackLayout)
    private var tabStackLayout

    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            let layoutPages = computeLayout(proxy: proxy).pages
            let pages = viewContent.pages.map { page in
                let placement = layoutPages[id: page.id]?.placement
                return GeneratedPage(id: page.id, content: page.content, placement: placement)
            }

            Color.clear
                .onChangeWithTransaction(of: layoutPages) { layout, tx in
                    var automaticProvider: AutomaticTransitionProvider?
                    if let provider = tx.transitionProvider {
                        automaticProvider = provider
                    } else if tx.enableAutomaticTransition {
                        automaticProvider = { pages in
                            let resolver = viewContent.automaticTransitionResolver
                            guard let t = resolver.resolve(transitioningPages: pages) else {
                                return .init(EmptyTransition(progress: .start))
                            }
                            return t
                        }
                    }

                    store.send(.update(.init(uniqueElements: pages), automaticProvider.map(TransitionResolver.automatic)))
                }
        }
    }

    func computeLayout(proxy: GeometryProxy) -> LayoutOutput {
        let layoutInput = LayoutInput.from(viewContent)
        let layoutProxy = TabStackLayoutProxy.from(layoutInput)
        let context = TabStackLayoutContext(
            bounds: proxy.boundsWithoutSafeAreaInsets,
            safeAreaInsets: proxy.safeAreaInsets)

        tabStackLayout.placePages(in: context, layout: layoutProxy)
        return .from(layoutProxy)
    }
}
