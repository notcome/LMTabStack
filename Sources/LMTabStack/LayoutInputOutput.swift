import ComposableArchitecture
import SwiftUI

struct LayoutInput: Equatable {
    var selectedTab: AnyTabID
    var tabs: IdentifiedArrayOf<Tab>
    var decorations: IdentifiedArrayOf<Page>

    struct Tab: Equatable, Identifiable {
        var id: AnyTabID
        var pages: IdentifiedArrayOf<Page>

        var preferredZIndex: Double?
    }

    struct Page: Equatable, Identifiable {
        var id: AnyPageID
        var layoutValues: PageLayoutValues

        static func from(_ page: ViewContent.Page) -> Self {
            .init(id: page.id, layoutValues: page.layoutValues)
        }
    }

    static func from(_ content: ViewContent) -> Self {
        let selectedTab = content.selectedTab
        let tabs = content.tabs.map { tab -> Tab in
            let pages = tab.pages.map(Page.from(_:))
            return Tab(
                id: tab.id,
                pages: .init(uniqueElements: pages),
                preferredZIndex: tab.section.containerValues.tabStackPreferredZIndex)
        }

        let decorations = content.decorations.map(Page.from(_:))
        return .init(
            selectedTab: selectedTab,
            tabs: .init(uniqueElements: tabs),
            decorations: .init(uniqueElements: decorations))
    }
}

struct LayoutOutput: Equatable {
    var pages: IdentifiedArrayOf<Page> = []

    struct Page: Equatable, Identifiable {
        var id: AnyPageID
        var placement: PagePlacement

        static func from(_ page: TabStackLayoutProxy.Page) -> Self? {
            guard let placement = page.placement.value else { return nil }
            return .init(id: page.id, placement: placement)
        }
    }

    static func from(_ proxy: TabStackLayoutProxy) -> Self {
        var result = Self()
        result.pages += proxy.decorations.compactMap(Page.from(_:))
        for tab in proxy.tabs {
            result.pages += tab.pages.compactMap(Page.from(_:))
        }
        return result
    }
}

public struct TabStackLayoutProxy {
    public internal(set) var selectedTab: AnyTabID
    public internal(set) var tabs: IdentifiedArrayOf<Tab>
    public internal(set) var decorations: IdentifiedArrayOf<Page>

    public struct Tab: Identifiable {
        public internal(set) var id: AnyTabID
        public internal(set) var pages: IdentifiedArrayOf<Page>
        public internal(set) var preferredZIndex: Double?
    }

    public struct Page: Identifiable {
        public internal(set) var id: AnyPageID
        public internal(set) var layoutValues: PageLayoutValues
        var placement: Box<PagePlacement?> = .init(value: nil)

        static func from(_ page: LayoutInput.Page) -> Self {
            .init(id: page.id, layoutValues: page.layoutValues)
        }

        public func place(
            at zIndex: Double,
            frame: CGRect,
            safeAreaInsets: EdgeInsets = .init()
        ) {
            placement.value = .init(
                zIndex: zIndex,
                frame: frame,
                safeAreaInsets: safeAreaInsets)
        }
    }

    static func from(_ content: LayoutInput) -> Self {
        let selectedTab = content.selectedTab
        let tabs = content.tabs.map { tab -> Tab in
            let pages = tab.pages.map(Page.from(_:))
            return Tab(
                id: tab.id,
                pages: .init(uniqueElements: pages),
                preferredZIndex: tab.preferredZIndex)
        }

        let decorations = content.decorations.map(Page.from(_:))
        return .init(
            selectedTab: selectedTab,
            tabs: .init(uniqueElements: tabs),
            decorations: .init(uniqueElements: decorations))
    }
}
