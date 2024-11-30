import IdentifiedCollections
import SwiftUI
import LMTabStack

struct AppTabBarPageID: Hashable & Sendable {}

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
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke()
                .foregroundStyle(.gray)
        }
        .padding(24)
        .environment(model)
        .environment(\.transitionProvider, SimpleTransitionProvider())
        .tabStackLayout(FullScreenTabStackLayout(model: model))
    }
}


struct SimpleTransitionView: View {
    var source: PageProxy
    var target: PageProxy
    var tabBar: PageProxy?
    var progress: TransitionProgress

    var body: some View {
        // Opacity
        Track(timing: .easeInOut(duration: 2)) {
            source.contentView
                .transitionOpacity(progress == .start ? 1 : 0)

            target.contentView
                .transitionOpacity(progress == .start ? 0 : 1)
        }

        // Morphing
        Track(timing: .easeInOut(duration: 0.5)) {
            source.contentView
                .pageTransition(\.inTransition, true)
//                .transitionOffset(y: progress == .start ? 0 : 1000)

            target.contentView
                .transitionScale(progress == .start ? 1e-3 : 1)
                .pageTransition(\.inTransition, true)

            if target.id == AnyPageID(HomePageID.child(.childB)) {
                source.transitionElement(HomeChildPage.childA)?
                    .transitionOffset(x: progress == .start ? 0 : -400)

                source.transitionElement(HomeChildPage.childB)?
                    .transitionBlurRadius(progress == .start ? 0 : 10)
            }

            if target.id == AnyPageID(HomePageID.child(.childA)) {
                source.transitionElement(HomeChildPage.childA)?
                    .transitionBlurRadius(progress == .start ? 0 : 10)

                source.transitionElement(HomeChildPage.childB)?
                    .transitionOffset(x: progress == .start ? 0 : 400)
            }


            if let tabBar {
                let disappear = if case .disappear = tabBar.behaivor {
                    true
                } else {
                    false
                }

                tabBar.contentView
                    .transitionOffset(y: disappear == (progress == .start) ? 0 : 100)
            }
        }
    }
}

struct SimpleTransitionProvider: TransitionProvider {
    func transitions(for transitioningPages: IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> AnyView {
        let tabBarID = AnyPageID(AppTabBarPageID())
        let tabBar = transitioningPages.first {
            $0.id == tabBarID
        }

        let source = transitioningPages.first {
            if $0.id != tabBarID, case .disappear = $0.behaivor {
                true
            } else {
                false
            }
        }

        let target = transitioningPages.first {
            if $0.id != tabBarID, case .appear = $0.behaivor {
                true
            } else {
                false
            }
        }

        guard let source, let target else { return AnyView(EmptyView()) }

        return AnyView(SimpleTransitionView(source: source, target: target, tabBar: tabBar, progress: progress))
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
    private enum InTransitionKey: PageTransitionKey {
        static var defaultValue: Bool { false }
    }

    var inTransition: Bool {
        get { self[InTransitionKey.self] }
        set { self[InTransitionKey.self] = newValue }
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
