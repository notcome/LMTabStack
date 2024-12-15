import ComposableArchitecture
import SwiftUI

extension ContainerValues {
    @Entry
    var transitionEffects = TransitionEffects()

    @Entry
    var transitionValues = PageTransitionValues()
}

public extension View {
    func transitionScale(x: CGFloat? = nil, y: CGFloat? = nil) -> some View {
        self.containerValue(\.transitionEffects.scaleX, x)
            .containerValue(\.transitionEffects.scaleY, y)
    }

    func transitionScale(_ k: CGFloat) -> some View {
        transitionScale(x: k, y: k)
    }

    func transitionOffset(x: CGFloat? = nil, y: CGFloat? = nil) -> some View {
        self.containerValue(\.transitionEffects.offsetX, x)
            .containerValue(\.transitionEffects.offsetY, y)
    }

    func transitionOffset(_ d: CGPoint) -> some View {
        transitionOffset(x: d.x, y: d.y)
    }

    func transitionOpacity(_ k: CGFloat) -> some View {
        self.containerValue(\.transitionEffects.opacity, k)
    }

    func transitionBlurRadius(_ r: CGFloat) -> some View {
        self.containerValue(\.transitionEffects.blurRadius, r)
    }
}

typealias AutomaticTransitionProvider = (TransitioningPages) -> AnyAutomaticTransition

//enum InteractiveTransitionProgress: Equatable {
//    case start
//    case end
//}

extension Transaction {
    @Entry
    var transitionProvider: AutomaticTransitionProvider?
//    @Entry
//    var interactiveTransitionProgress: InteractiveTransitionProgress?
//
//    public var isInteractiveTransition: Bool {
//        interactiveTransitionProgress != nil
//    }
}

public func withTransitionProvider<T: AutomaticTransition>(
    _ provider: @escaping (TransitioningPages) -> T,
    action: () -> Void
) {
    var transaction = Transaction()
    transaction.transitionProvider = { pages in
        let transition = provider(pages)
        return AnyAutomaticTransition(transition)
    }
    withTransaction(transaction) {
        action()
    }
}

extension ContainerValues {
    @Entry
    var viewRef: ViewRef? = nil

    @Entry
    var pageTransitionTiming: TransitionAnimation? = nil
}

enum ViewRef: Hashable {
    case content(AnyPageID)
    case wrapper(AnyPageID)
    case transitionElement(TransitionElementProxy.ID)
    case morphingView(MorphingViewProxy.ID)

    var pageID: AnyPageID {
        switch self {
        case .content(let pageID), .wrapper(let pageID):
            pageID
        case .transitionElement(let id):
            id.pageID
        case .morphingView(let id):
            id.pageID
        }
    }
}

struct ViewRefView {
    var ref: ViewRef
}

extension ViewRefView: View {
    var body: some View {
        Color.clear
            .containerValue(\.viewRef, ref)
    }
}

public struct Track<Content: View>: View {
    public var timing: TransitionAnimation

    @ViewBuilder
    public var content: Content

    public init(timing: TransitionAnimation, @ViewBuilder content: () -> Content) {
        self.timing = timing
        self.content = content()
    }

    public var body: some View {
        Section {
            content
        }
        .containerValue(\.pageTransitionTiming, timing)
    }
}

extension Transaction {
    @Entry
    var transitionAnimation: TransitionAnimation?
}
