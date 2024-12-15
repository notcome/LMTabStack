import SwiftUI

struct PageHostingViewPureBackend: View {
    var content: AnyView

    @Environment(PageStore.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content
                    .safeAreaPadding(store.resolvedPlacement.safeAreaInsets)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                        summary.pageAnchor = pageAnchor
                    }
                    .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
                    .modifier(store.transition?.contentEffects ?? .init())
                    .zIndex(0)

                if let morphingViews = store.transition?.morphingViews {
                    ForEach(morphingViews) { morphingView in
                        morphingView
                            .content
                            .modifier(morphingView.effects)
                            .zIndex(morphingView.zIndex)
                    }
                }
            }
            .modifier(store.transition?.wrapperEffects ?? .init())
        }
    }
}
