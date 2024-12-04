import ComposableArchitecture
import LMTabStack
import SwiftUI

struct SideBySide: TransitionDefinition {
    var childA: PageProxy
    var childB: PageProxy
    var childAToChildB: Bool

    var gestureOffset: CGFloat

    enum MorphingViewID: Hashable {
        case background
    }

    var morphingViews: some View {
        MorphingViewGroup(for: childA.id) {
            MorphingView(for: MorphingViewID.background) {
                GeometryReader { proxy in
                    HomeChildPage.childA.color
                        .frame(width: proxy.size.width * 2)
                        .frame(width: proxy.size.width, alignment: .trailing)
                }
                .ignoresSafeArea()
                .morphingViewContentZIndex(-1)
            }
        }
        MorphingViewGroup(for: childB.id) {
            MorphingView(for: MorphingViewID.background) {
                GeometryReader { proxy in
                    HomeChildPage.childB.color
                        .frame(width: proxy.size.width * 2)
                        .frame(width: proxy.size.width, alignment: .leading)
                }
                .ignoresSafeArea()
                .morphingViewContentZIndex(-1)
            }
        }
    }

    var width: CGFloat {
        childA.frame.width
    }

    var offset: CGFloat {
        func compress(_ x: Double) -> Double {
            // Maps [0,∞) to [0,1)
            let tension = 0.55
            return 1 - (1 / (x * tension + 1))
        }

        func f(_ x: Double) -> Double {
            if x < 0 {
                return -compress(-x)
            } else if x <= 1 {
                return x
            } else {
                return 1 + compress(x - 1)
            }
        }

        // t = 0 start, t = 1 end
        if childAToChildB {
            let t = -1 * gestureOffset / width
            return f(t)
        } else {
            let t = gestureOffset / width
            return f(t)
        }
    }

    func lerp(from start: CGFloat, to end: CGFloat, t: CGFloat) -> CGFloat {
        start + (end - start) * t
    }

    var childAOffset: CGFloat {
        if childAToChildB {
            lerp(from: 0, to: -width, t: offset)
        } else {
            lerp(from: -width, to: 0, t: offset)
        }
    }

    var childBOffset: CGFloat {
        if childAToChildB {
            lerp(from: width, to: 0, t: offset)
        } else {
            lerp(from: 0, to: width, t: offset)
        }
    }

    func transitions(morphingViews: MorphingViewsProxy) -> some View {
        Track(timing: .spring) {
            childA.wrapperView
                .transitionOffset(x: childAOffset)
            childB.wrapperView
                .transitionOffset(x: childBOffset)
        }
    }
}

struct SideBySideProvider: TransitionProvider {
    func transitions(for transitioningPages: IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> any TransitionDefinition {
        guard let childA = transitioningPages[id: AnyPageID(HomePageID.child(.childA))],
              let childB = transitioningPages[id: AnyPageID(HomePageID.child(.childB))]
        else { return .empty }

        var transition = SideBySide(childA: childA, childB: childB, childAToChildB: true, gestureOffset: 0)

        switch (childA.behaivor, childB.behaivor) {
        case (.disappear, .appear):
            transition.childAToChildB = true
            transition.gestureOffset = progress == .start ? 0 : -childA.frame.width
        case (.appear, .disappear):
            transition.childAToChildB = false
            transition.gestureOffset = progress == .start ? 0 : childA.frame.width
        default:
            return .empty
        }
        return transition
    }
}
