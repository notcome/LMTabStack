import ComposableArchitecture
import LMTabStack
import SwiftUI

struct HomeToChild: AutomaticTransition {
    var home: PageProxy
    var child: PageProxy
    var tabBar: PageProxy
    var rootToChild: Bool

    var progress: TransitionProgress = .start

    var childID: HomeChildPage
    var childA: TransitionElementProxy
    var childB: TransitionElementProxy

    init?(home: PageProxy, child: PageProxy, tabBar: PageProxy, rootToChild: Bool) {
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
            RoundedRectangle(cornerRadius: atStart ? 30 : 55)
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
                    cardSize: cardOpened.frame.size,
                    finalSize: child.frame.size,
                    rootToChild: rootToChild)
            }

            MorphingView(for: MorphingViewID.cardContent) {
                Text(childID.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    func transitions(morphingViews: MorphingViewsProxy) -> some View {
        let atStart = rootToChild == (progress == .start)

        // Opacity
        Track(timing: .easeOut) {
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
        Track(timing: .spring) {
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

            let cardFrame = childOpened.frame
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
            otherChild
                .transitionOffset(x: otherChildXOffset)
                .transitionBlurRadius(atStart ? 0 : 10)
        }
    }
}

func rootToChildProvider(_ transitioningPages: TransitioningPages) -> HomeToChild {
    let tabBar = transitioningPages[id: AppTabBarPageID()]!
    let home = transitioningPages[id: HomePageID.root]!
    let childA = transitioningPages[id: HomePageID.child(.childA)]
    let childB = transitioningPages[id: HomePageID.child(.childB)]

    let child: PageProxy = (childA ?? childB)!

    return HomeToChild(home: home, child: child, tabBar: tabBar, rootToChild: home.behavior.isDisappearing)!
}
