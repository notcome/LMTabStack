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
                    store.send(.update(.init(uniqueElements: pages), tx.transitionProvider.map(TransitionResolver.automatic)))
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
