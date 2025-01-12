import ComposableArchitecture
import SwiftUI

private struct _Page: ViewModifier {
    @Environment(\.pageCoordinator)
    private var coordinator

    func body(content: Content) -> some View {
        content
            .modifier(PageModifier())
            .backgroundPreferenceValue(TransitionElementSummary.self) { summary in
                GeometryReader { proxy in
                    if let mountedLayout = convertToMountedLayout(summary: summary, proxy: proxy) {
                        Color.clear
                            .onChange(of: mountedLayout, initial: true) {
                                coordinator!.update(mountedLayout: mountedLayout)
                            }
                    }
                }
            }
            .opacity(coordinator!.hidden ? 0 : 1)
            .ignoresSafeArea(.all)
            .allowsHitTesting(coordinator!.committedTransitionToken != nil)
    }

    func convertToMountedLayout(summary: TransitionElementSummary, proxy: GeometryProxy) -> PageMountedLayout? {
        guard let pageAnchor = summary.pageAnchor else { return nil }
        return .init(
            transitionToken: summary.transitionToken,
            pageFrame: proxy[pageAnchor],
            transitionElements: summary.elements.mapValues { proxy[$0] })
    }
}

public struct Page<ID: Hashable & Sendable, Content: View>: View {
    var id: ID
    var content: Content

    @Environment(\.tabStackCoordinator)
    private var tabStackCoordinator

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
            if let coordinator = tabStackCoordinator!.pageCoordinator(for: id) {
                content
                    .modifier(_Page())
                    .environment(\.pageCoordinator, coordinator)
            }
        }
        .tag(id)
        .id(id)
    }
}
