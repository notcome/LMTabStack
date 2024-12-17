import IdentifiedCollections
import SwiftUI
import LMTabStack

struct AppTabBarPageID: Hashable & Sendable {}

private struct WithBorderModifier: ViewModifier {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .compact {
            content
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke()
                        .foregroundStyle(.gray)
                }
                .padding(24)
        }
    }
}

extension View {
    func withBorder() -> some View {
        modifier(WithBorderModifier())
    }
}

struct ContentView: View {
    @State
    private var model = AppModel()

    var body: some View {
        TabStackView(selection: $model.selectedTab) {
            CalendarStack()
            HomeStack()
            ProgressStack()

            Page(id: AppTabBarPageID()) {
                AppTabBar(selectedTab: $model.selectedTab)
            }
        }
        .withBorder()
        .environment(model)
        .tabStackLayout(FullScreenTabStackLayout(model: model))
        .environment(\.tabStackRenderingMode, .hybrid)
    }
}

struct FullScreenTabStackLayout: TabStackLayout {
    var model: AppModel

    func placePages(in context: TabStackLayoutContext, layout: TabStackLayoutProxy) {
        let selectedTab = layout.tabs[id: layout.selectedTab]!
        let last = selectedTab.pages.last!
        var safeAreaInsets = context.safeAreaInsets

        if model.showsTabBar {
            let tabBar = layout.decorations[id: AnyPageID(AppTabBarPageID())]!

            let height: CGFloat = 48
            let padding: CGFloat = 24
            let y = context.bounds.maxY - context.safeAreaInsets.bottom - height - padding
            let frame = CGRect(x: 0, y: y, width: context.bounds.width, height: height)
            tabBar.place(at: 10, frame: frame, safeAreaInsets: .init())

            let d = max(safeAreaInsets.bottom, context.bounds.maxY - frame.minY)
            safeAreaInsets.bottom = d
        }

        last.place(
            at: Double(selectedTab.pages.count),
            frame: context.bounds,
            safeAreaInsets: safeAreaInsets)
    }
}


extension PageTransitionValues {
    private enum AtStartKey: PageTransitionKey {
        static var defaultValue: Bool? { nil }
    }

    var atStart: Bool? {
        get { self[AtStartKey.self] }
        set { self[AtStartKey.self] = newValue }
    }

    var inTransition: Bool {
        atStart != nil
    }
}

private struct PageBackgroundModifier<Style: ShapeStyle>: ViewModifier {
    @PageTransition(\.inTransition)
    var inTransition

    var style: Style
    var hidesInTransition: Bool

    var resolvedStyle: AnyShapeStyle {
        if inTransition, hidesInTransition {
            return AnyShapeStyle(.clear)
        }
        return AnyShapeStyle(style)
    }

    func body(content: Content) -> some View {
        content
            .background(resolvedStyle, ignoresSafeAreaEdges: .all)
    }
}

extension View {
    func pageBackground(_ style: some ShapeStyle, hidesInTransition: Bool = true) -> some View {
        modifier(PageBackgroundModifier(style: style, hidesInTransition: hidesInTransition))
    }
}

#Preview {
    ContentView()
}
