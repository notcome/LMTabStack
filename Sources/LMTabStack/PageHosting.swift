import ComposableArchitecture
import SwiftUI

public struct Page<ID: Hashable & Sendable, Content: View>: View {
    var id: ID
    var content: Content

    @Environment(TabStackStore.self)
    private var store

    public init(
        id: ID,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            let id = AnyPageID(id)
            let childStore = store.scope(state: \.loadedPages[id: id], action: \.loadedPages[id: id]) as PageHostingStore?
            if let childStore {
                PageHostingView(
                    store: childStore,
                    content: content,
                    proxy: proxy,
                    transitionProgress: store.transitionProgress
                )
                .environment(childStore)
            }
        }
        .tag(AnyPageID(id))
    }
}

struct PageHostingView<Content: View>: View {
    var store: StoreOf<PageHostingFeature>
    var content: Content
    var proxy: GeometryProxy
    var transitionProgress: TransitionProgress?

    var id: AnyPageID { store.id }

    var body: some View {
        let bounds = proxy.boundsWithoutSafeAreaInsets
        let state = store.state
        let placement = state.placement(for: transitionProgress)
        let opacity = state.opacity(for: transitionProgress)

        content
            .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
            .safeAreaPadding(placement.safeAreaInsets)
            .modifier(store.transitionEffects ?? .init())
            .absolutePlacement(frame: placement.frame, parentBounds: bounds)
            .opacity(opacity)
            .onPreferenceChange(TransitionElementSummary.self) { summary in
                store.send(.syncTransitionElements(summary))
            }
    }
}
