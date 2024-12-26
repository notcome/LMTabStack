import SwiftUI

struct PageHostingViewPureBackend: View {
    var content: AnyView

    @Environment(\.pageCoordinator)
    private var coordinator

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                let placement = coordinator!.placement
                let transitionToken = coordinator!.committedTransitionToken

                content
                    .safeAreaPadding(placement.safeAreaInsets)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                        summary.transitionToken = transitionToken
                        summary.pageAnchor = pageAnchor
                    }
                    .environment(\.pageVisiblity, coordinator!.hidden ? .invisible : .visible)
//                    .modifier(store.transition?.contentEffects ?? .init())
                    .zIndex(0)
            }
//            .modifier(store.transition?.wrapperEffects ?? .init())
        }
    }
}
