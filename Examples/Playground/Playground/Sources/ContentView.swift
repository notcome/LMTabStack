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

struct HomeToChild: TransitionDefinition {
    var home: PageProxy
    var child: PageProxy
    var tabBar: PageProxy

    var rootToChild: Bool
    var progress: TransitionProgress

    enum MorphingViewID: Hashable {
        case cardBackground
        case cardContent
    }

    var childID: HomeChildPage {
        switch child.id.base as! HomePageID {
        case .child(let childID):
            return childID
        default:
            fatalError()
        }
    }

    struct MorphingCardBackground: View {
        var childID: HomeChildPage
        var finalSize: CGSize
        var rootToChild: Bool

        @PageTransition(\.atStart)
        var atStart_

        var atStart: Bool {
            atStart_ ?? rootToChild
        }

        var body: some View {
            RoundedRectangle(cornerRadius: atStart ? 30 : 24)
                .foregroundStyle(childID == .childA ? .yellow : .blue)
                .frame(
                    width: atStart ? 240 : finalSize.width,
                    height: atStart ? 120 : finalSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(duration: 0.5), value: atStart)
                .morphingViewContentZIndex(-1)
        }
    }

    var morphingViews: some View {
        MorphingViewGroup(for: child.id.base as! HomePageID) {
            MorphingView(for: MorphingViewID.cardBackground) {
                MorphingCardBackground(childID: childID, finalSize: child.frame.size, rootToChild: rootToChild)
            }

            MorphingView(for: MorphingViewID.cardContent) {
                Text(childID.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func transitions(morphingViews: MorphingViewsProxy) -> some View {
        let atStart = rootToChild == (progress == .start)

        // Opacity
        Track(timing: .easeIn(duration: 1)) {
            child.contentView
                .transitionOpacity(atStart ? 0 : 1)
                .transitionBlurRadius(atStart ? 10 : 0)
                .pageTransition(\.atStart, atStart)

            if let content = morphingViews.morphingView(pageID: child.id, morphingViewID: MorphingViewID.cardContent) {
                content
                    .transitionOpacity(atStart ? 1 : 0)
                    .transitionBlurRadius(atStart ? 0 : 10)
            }
        }

        // Movement
        Track(timing: .spring(duration: 0.5)) {
            tabBar.contentView
                .transitionOffset(y: atStart ? 0 : 144)

            child.contentView
                .transitionScale(atStart ? 1e-3 : 1)

            if let childA = home.transitionElement(HomeChildPage.childA),
               let childB = home.transitionElement(HomeChildPage.childB)
            {
                MorphingMovement(
                    home: home,
                    child: child,
                    morphingViews: morphingViews,
                    childA: childA,
                    childB: childB,
                    childID: childID,
                    atStart: atStart
                )
            }
        }
    }

    struct MorphingMovement: View {
        var home: PageProxy
        var child: PageProxy
        var morphingViews: MorphingViewsProxy
        var childA: TransitionElementProxy
        var childB: TransitionElementProxy
        var childID: HomeChildPage
        var atStart: Bool

        var childOpened: TransitionElementProxy {
            childID == .childA ? childA : childB
        }
        var otherChild: TransitionElementProxy {
            childID == .childA ? childB : childA
        }

        var wrapperOffset: CGPoint {
            guard atStart else { return .zero }

            let cardFrame = child[childOpened]
            let sx = cardFrame.midX
            let sy = cardFrame.midY
            let ex = child.frame.midX
            let ey = child.frame.midY
            return .init(x: sx - ex, y: sy - ey)
        }

        var otherChildXOffset: CGFloat {
            guard !atStart else { return 0 }
            return childID == .childA ? 1000 : -1000
        }


        var body: some View {
            // move frame card center to page center
            child.wrapperView
                .transitionOffset(wrapperOffset)

            childOpened.transitionOpacity(0)
            otherChild.transitionOffset(x: otherChildXOffset)
        }

    }
}

struct SimpleTransitionProvider: TransitionProvider {
    func transitions(for transitioningPages: IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> any TransitionDefinition {
        var tabBar: PageProxy?
        var pages: [HomePageID: PageProxy] = [:]

        for page in transitioningPages {
            if page.id == AnyPageID(AppTabBarPageID()) {
                tabBar = page
                continue
            }

            if let id = page.id.base as? HomePageID {
                pages[id] = page
            }
        }

        guard pages.count == 2 else { return .empty }
        if let root = pages[.root] {
            let child = (pages[.child(.childA)] ?? pages[.child(.childB)])!

            let rootToChild = if case .disappear = root.behaivor {
                true
            } else {
                false
            }

            return HomeToChild(
                home: root,
                child: child,
                tabBar: tabBar!,
                rootToChild: rootToChild,
                progress: progress)
        }

        return .empty
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
