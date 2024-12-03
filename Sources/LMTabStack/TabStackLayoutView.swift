import ComposableArchitecture
import SwiftUI

struct TabStackLayoutView: Equatable {
    var input: LayoutInput
}

extension TabStackLayoutView: View {
    var body: some View {
        _TabStackLayoutView(input: input)
    }
}

private struct _TabStackLayoutView: View {
    var input: LayoutInput

    @Environment(\.tabStackLayout)
    private var tabStackLayout

    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            let layout = computeLayout(proxy: proxy)
            Color.clear
                .onChangeWithTransaction(of: layout) { layout, tx in
                    let animated = !tx.disablesAnimations && tx.animation != nil
                    let cvs = TabStackFeature.CurrentViewState(
                        animated: animated,
                        transitionProvider: tx.transitionProvider,
                        layout: layout)
                    store.send(.sync(.currentViewState(cvs)))
                }
        }
    }

    func computeLayout(proxy: GeometryProxy) -> LayoutOutput {
        let layoutProxy = TabStackLayoutProxy.from(input)
        let context = TabStackLayoutContext(
            bounds: proxy.boundsWithoutSafeAreaInsets,
            safeAreaInsets: proxy.safeAreaInsets)

        tabStackLayout.placePages(in: context, layout: layoutProxy)
        return .from(layoutProxy)
    }
}

