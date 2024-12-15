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
            let childStore = store.scope(state: \.pages[id: id], action: \.pages[id: id]) as PageStore?
            if let childStore {
                PageHostingView(
                    store: childStore,
                    content: AnyView(content)
                )
                .environment(childStore)
            }
        }
        .tag(id)
        .id(id)
    }
}

struct PageHostingView: View {
    var store: PageStore
    var content: AnyView

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    var body: some View {
        let opacity = store.resolvedOpacity
        let frame = store.resolvedPlacement.frame

        Group {
            switch renderingMode {
            case .pure:
                PageHostingViewPureBackend(content: content)
            case .hybrid:
                PageHostingViewHybridBackend(content: content)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
        .backgroundPreferenceValue(TransitionElementSummary.self) { summary in
            GeometryReader { proxy in
                if let mountedLayout = convertToMountedLayout(summary: summary, proxy: proxy) {
                    Color.clear
                        .onChange(of: mountedLayout, initial: true) {
                            store.send(.syncMountedLayout(mountedLayout))
                        }
                }
            }
        }
        .opacity(opacity)
        .environment(store)
        .ignoresSafeArea(.all)
    }

    func convertToMountedLayout(summary: TransitionElementSummary, proxy: GeometryProxy) -> PageMountedLayout? {
        guard let pageAnchor = summary.pageAnchor else { return nil }
        return .init(
            pageFrame: proxy[pageAnchor],
            transitionElements: summary.elements.mapValues { proxy[$0] })
    }
}
