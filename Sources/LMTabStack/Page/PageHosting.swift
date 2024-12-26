import ComposableArchitecture
import SwiftUI

protocol TabStackCoordinator {
    func pageCoordinator(for pageID: AnyPageID) -> (any PageCoordinator)?
    func viewTransitionModel(for viewRef: ViewRef) -> any ViewTransitionModel
}

protocol PageCoordinator {
    var id: AnyPageID { get }

    var placement: PagePlacement { get }
    var hidden: Bool { get }

    var committedTransitionToken: Int? { get }

    func update(mountedLayout: PageMountedLayout)
}

extension EnvironmentValues {
    @Entry
    var tabStackCoordinator: (any TabStackCoordinator)? = nil
    @Entry
    var pageCoordinator: (any PageCoordinator)? = nil
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
                PageHostingView(
                    coordinator: coordinator,
                    content: AnyView(content)
                )
                .environment(\.pageCoordinator, coordinator)
            }
        }
        .tag(id)
        .id(id)
    }
}

struct PageHostingView: View {
    var coordinator: PageCoordinator
    var content: AnyView

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    @Environment(\.tabStackCoordinator)
    private var tabStackCoordinator

    var body: some View {
        let frame = coordinator.placement.frame

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
                            coordinator.update(mountedLayout: mountedLayout)
                        }
                }
            }
        }
        .opacity(coordinator.hidden ? 0 : 1)
        .environment(\.viewTransitionModel, tabStackCoordinator!.viewTransitionModel(for: .page(coordinator.id)))
        .ignoresSafeArea(.all)
        .allowsHitTesting(coordinator.committedTransitionToken != nil)
    }

    func convertToMountedLayout(summary: TransitionElementSummary, proxy: GeometryProxy) -> PageMountedLayout? {
        guard let pageAnchor = summary.pageAnchor else { return nil }
        return .init(
            transitionToken: summary.transitionToken,
            pageFrame: proxy[pageAnchor],
            transitionElements: summary.elements.mapValues { proxy[$0] })
    }
}
