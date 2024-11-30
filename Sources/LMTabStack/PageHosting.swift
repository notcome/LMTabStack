import ComposableArchitecture
import SwiftUI

extension ContainerValues {
    @Entry
    var pageContent: AnyView?
}


public struct Page<ID: Hashable & Sendable, Content: View>: View {
    var id: ID
    var content: Content

    public init(
        id: ID,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.content = content()
    }

    public var body: some View {
        Color.clear
            .tag(AnyPageID(id))
            .containerValue(\.pageContent, AnyView(content))
    }
}

//
//Group {
//    let id = AnyPageID(id)
//    let childStore = store.scope(state: \.loadedPages[id: id], action: \.loadedPages[id: id]) as PageHostingStore?
//    if let childStore {
//        PageHostingView(
//            store: childStore,
//            content: content,
//            transitionProgress: store.transitionProgress
//        )
//        .environment(childStore)
//    }
//}

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
            .modifier(store.wrapperTransitionEffects ?? .init())
            .absolutePlacement(frame: placement.frame, parentBounds: bounds)
            .opacity(opacity)
            .onPreferenceChange(TransitionElementSummary.self) { summary in
                store.send(.syncTransitionElements(summary))
            }
        }
        .environment(store)
    }
}
