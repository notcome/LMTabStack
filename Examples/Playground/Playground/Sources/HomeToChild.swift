import ComposableArchitecture
import LMTabStack
import SwiftUI

struct HomeToChild: TransitionDefinition {
    var home: PageProxy
    var child: PageProxy
    var tabBar: PageProxy
    var rootToChild: Bool
    var progress: TransitionProgress

    var childID: HomeChildPage
    var childA: TransitionElementProxy
    var childB: TransitionElementProxy

    init?(home: PageProxy, child: PageProxy, tabBar: PageProxy, rootToChild: Bool, progress: TransitionProgress) {
        guard let childA = home.transitionElement(HomeChildPage.childA),
              let childB = home.transitionElement(HomeChildPage.childB)
        else {
            print("Cannot construct HomeToChild because missing childA/childB")
            return nil
        }

        self.home = home
        self.child = child
        self.tabBar = tabBar
        self.rootToChild = rootToChild
        self.progress = progress

        switch child.id.base as! HomePageID {
        case .child(let childID):
            self.childID =  childID
        default:
            fatalError()
        }

        self.childA = childA
        self.childB = childB
    }

    enum MorphingViewID: Hashable {
        case cardBackground
        case cardContent
    }

    struct MorphingCardBackground: View {
        var childID: HomeChildPage
        var cardSize: CGSize
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
                    width: atStart ? cardSize.width : finalSize.width,
                    height: atStart ? cardSize.height : finalSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .morphingViewContentZIndex(-1)
        }
    }

    var morphingViews: some View {
        MorphingViewGroup(for: child.id) {
            MorphingView(for: MorphingViewID.cardBackground) {
                let cardOpened = switch childID {
                case .childA:
                    childA
                case .childB:
                    childB
                }
                MorphingCardBackground(
                    childID: childID,
                    cardSize: home[cardOpened].size,
                    finalSize: child.frame.size,
                    rootToChild: rootToChild)
            }

            MorphingView(for: MorphingViewID.cardContent) {
                Text(childID.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func transitions(morphingViews: MorphingViewsProxy) -> some View {
        let _ = print("at start", rootToChild == (progress == .start), rootToChild, progress)
        let atStart = rootToChild == (progress == .start)

        // Opacity
        Track(timing: .easeOut(duration: 0.5)) {
            child.contentView
                .transitionOpacity(atStart ? 0 : 1)
                .transitionBlurRadius(atStart ? 10 : 0)

            if let content = morphingViews.morphingView(pageID: child.id, morphingViewID: MorphingViewID.cardContent) {
                content
                    .transitionOpacity(atStart ? 1 : 0)
                    .transitionBlurRadius(atStart ? 0 : 10)
            }
        }

        // Movement
        Track(timing: .spring(duration: 0.5, bounce: 0)) {
            let _ = print("track movement tab bar dy=", atStart ? 0 : 144)
            tabBar.contentView
                .transitionOffset(y: atStart ? 0 : 144)

            child.contentView
                .transitionScale(atStart ? 1e-3 : 1)
                .pageTransition(\.atStart, atStart)

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

struct RootToChildProvider: TransitionProvider {
    func transitions(for transitioningPages: IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> any TransitionDefinition {
        print("request transition with progress", progress)

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

        guard pages.count == 2 else {
            print("Empty because we don't have two pages. Found", Array(pages.keys))
            return .empty
        }
        if let root = pages[.root] {
            let child = (pages[.child(.childA)] ?? pages[.child(.childB)])!

            let rootToChild = if case .disappear = root.behaivor {
                true
            } else {
                false
            }

            guard let transition = HomeToChild(
                home: root,
                child: child,
                tabBar: tabBar!,
                rootToChild: rootToChild,
                progress: progress)
            else { return .empty }

            print("request transition with progress", progress, "actually non-empty")

            return transition
        }

        print("Empty because no root")
        return .empty
    }
}
