import ComposableArchitecture
import SwiftUI

struct ViewContent {
    var selectedTab: AnyTabID
    var tabs: IdentifiedArrayOf<Tab>
    var decorations: IdentifiedArrayOf<Page>

    struct Tab: Identifiable {
        var id: AnyTabID
        var section: SectionConfiguration
        var pages: IdentifiedArrayOf<Page>
    }

    struct Page: Identifiable {
        var id: AnyPageID
        var content: AnyView
        var layoutValues: PageLayoutValues
    }

    var pages: IdentifiedArrayOf<Page> {
        tabs.reduce(into: decorations) { $0 += $1.pages }
    }

    static func from(_ content: SectionCollection, selectedTab: some Hashable & Sendable) -> Self {
        var decorations: IdentifiedArrayOf<Page> = []

        let tabs = content.compactMap { section -> Tab? in
            let pages = section.content.compactMap { subview -> Page? in
                guard let id = subview.containerValues.tag(for: AnyPageID.self) else {
                    assertionFailure("Each page in a TabStackView should be wrapped by a Page.")
                    return nil
                }
                return .init(
                    id: id,
                    content: AnyView(subview),
                    layoutValues: subview.containerValues.pageLayoutValues)
            }

            guard let id = section.containerValues.tag(for: AnyTabID.self) else {
                decorations += pages
                return nil
            }
            precondition(
                type(of: selectedTab) == type(of: id.base),
                "Encountered a tab id with unexpected type: \(id.base)"
            )

            return Tab(id: id, section: section, pages: .init(uniqueElements: pages))
        }

        return .init(
            selectedTab: AnyTabID(selectedTab),
            tabs: .init(uniqueElements: tabs),
            decorations: decorations
        )
    }
}
