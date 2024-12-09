import ComposableArchitecture
import SwiftUI

extension ContainerValues {
    @Entry
    var pageContent: AnyView?
}


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
        let id = AnyPageID(id)
        GeometryReader { _ in
            let childStore = store.scope(state: \.loadedPages[id: id], action: \.loadedPages[id: id]) as PageHostingStore?
            if let childStore {
                PageHostingView(
                    store: childStore,
                    content: AnyView(content),
                    transitionProgress: store.transitionProgress
                )
                .environment(childStore)
            }
        }
        .onAppear {
            print("on appear", id.base)
        }
        .tag(id)
        .id(id)
    }
}

struct PageHostingView: View {
    var store: StoreOf<PageHostingFeature>
    var content: AnyView
    var transitionProgress: TransitionProgress?

    var id: AnyPageID { store.id }

    var body: some View {
        GeometryReader { proxy in
            let bounds = proxy.boundsWithoutSafeAreaInsets
            let state = store.state
            let placement = state.placement(for: transitionProgress)
            let opacity = state.opacity(for: transitionProgress)

            ZStack {
                content
                    .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
                    .safeAreaPadding(placement.safeAreaInsets)
                    .modifier(store.transitionEffects ?? .init())
                    .zIndex(0)

                ForEach(store.morphingViewContents) { content in
                    content.content
                        .modifier(store.morphingViewEffects[content.id] ?? .init())
                        .zIndex(content.zIndex ?? 0)

                }
            }
            .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                summary.pageAnchor = pageAnchor
            }
            .modifier(store.wrapperTransitionEffects ?? .init())
            .absolutePlacement(frame: placement.frame, parentBounds: bounds)
            .opacity(opacity)
            .onPreferenceChange(TransitionElementSummary.self) { summary in
                let _ = print("sync transition elements", summary.elements.keys.map(\.base))
                store.send(.syncTransitionElements(summary))
            }
        }
        .environment(store)
    }
}
