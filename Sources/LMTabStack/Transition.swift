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

@MainActor
public protocol TransitionProvider {
    func transitions(
        for transitioningPages: IdentifiedArrayOf<PageProxy>,
        progress: TransitionProgress
    ) -> any TransitionDefinition
}

struct EmptyTransitionProvider: TransitionProvider {
    func transitions(for transitioningPages: IdentifiedArrayOf<PageProxy>, progress: TransitionProgress) -> any TransitionDefinition {
        EmptyTransitionDefinition()
    }
}

enum InteractiveTransitionProgress: Equatable {
    case start
    case end
}

extension Transaction {
    @Entry
    public var transitionProvider: (any TransitionProvider)? = nil
    @Entry
    var interactiveTransitionProgress: InteractiveTransitionProgress?

    public var isInteractiveTransition: Bool {
        interactiveTransitionProgress != nil
    }
}

public func withTransitionProvider(_ provider: any TransitionProvider, action: () -> Void) {
    var transaction = Transaction()
    transaction.transitionProvider = provider
    withTransaction(transaction) {
        action()
    }
}

public struct PageProxy: Identifiable, Equatable {
    @EqualityIgnored
    var globalProxy: GeometryProxy

    init?(state: PageHostingFeature.State, globalProxy: GeometryProxy, pageAnchor: Anchor<CGRect>) {
        guard let transitionBehavior = state.transitionBehavior else { return nil }
        self.globalProxy = globalProxy
        self.pageAnchor = pageAnchor

        id = state.id
        behaivor = transitionBehavior
        frame = state.placement.frame
        transitionElements = [:]
        for element in state.transitionElements {
            transitionElements[element.id] = element.anchor
        }
    }

    public var id: AnyPageID
    public var behaivor: PageTransitionBehavior
    public var frame: CGRect

    var pageAnchor: Anchor<CGRect>
    var transitionElements: [AnyTransitionElementID: Anchor<CGRect>]

    public var contentView: some View {
        ViewRefView(ref: .content(id))
    }

    public var wrapperView: some View {
        ViewRefView(ref: .wrapper(id))
    }

    public func transitionElement(_ id: some Hashable & Sendable) -> TransitionElementProxy? {
        let id = AnyTransitionElementID(id)
        guard let anchor = transitionElements[id] else { return nil }
        return .init(id: .init(pageID: self.id, elementID: id), anchor: anchor)
    }

    public subscript(proxy: TransitionElementProxy) -> CGRect {
        var rect = globalProxy[proxy.anchor]
        let pageFrame = globalProxy[pageAnchor]

        rect.origin.x -= pageFrame.origin.x
        rect.origin.y -= pageFrame.origin.y
        return rect
    }
}

public struct TransitionElementProxy: Identifiable {
    public struct ID: Hashable {
        public var pageID: AnyPageID
        public var elementID: AnyTransitionElementID
    }

    public var id: ID
    var anchor: Anchor<CGRect>
}

extension TransitionElementProxy: View {
    public var body: some View {
        ViewRefView(ref: .transitionElement(id))
    }
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

extension ContainerValues {
    @Entry
    var viewRef: ViewRef? = nil

    @Entry
    var pageTransitionTiming: TransitionAnimation? = nil
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

struct TransitionGenerator: View {
    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            WithViewStore(
                store,
                observe: { state -> _TransitionGeneratorEq? in
                    let progress = store.transitionProgress
                    guard let progress else { return nil }
                    var pageProxies: IdentifiedArrayOf<PageProxy> = []
                    for page in store.loadedPages {
                        // We only generate transition when the page is fully loaded
                        guard let pageAnchor = page.pageAnchor else { return nil }
                        if let pageProxy = PageProxy(state: page, globalProxy: proxy, pageAnchor: pageAnchor) {
                            pageProxies.append(pageProxy)
                        }
                    }
                    return .init(
                        token: store.transitionUpdateToken,
                        progress: progress,
                        pageProxies: pageProxies)
                }, content: { scopedStore in
                    if let view = scopedStore.state {
                        view.equatable()
                    }
                })
        }
    }
}

struct _TransitionGeneratorEq: Equatable {
    var token: Int
    var progress: TransitionProgress
    var pageProxies: IdentifiedArrayOf<PageProxy>
}

extension _TransitionGeneratorEq: View {
    var body: some View {
        let _ = print("eq changed")
        _TransitionGenerator(token: token, progress: progress, pageProxies: pageProxies)
    }
}

struct Pair<LHS: Equatable, RHS: Equatable>: Equatable {
    var lhs: LHS
    var rhs: RHS
}

struct _TransitionGenerator: View {
    var token: Int
    var progress: TransitionProgress
    var pageProxies: IdentifiedArrayOf<PageProxy>

    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        let transitionDefinition = self.transitionDefinition
        Group(sections: transitionDefinition.erasedMorphingViews) { sections in
            let morphingViews = MorphingViewsProxy.from(sections)
            let transitions = transitionDefinition.erasedTransitions(morphingViews: morphingViews)
            Group(sections: transitions) { sections in
                let deps = Pair(lhs: token, rhs: Pair(lhs: progress, rhs: pageProxies))
                Color.clear
                    .onChange(of: deps, initial: true) {
                        update(sections: sections)
                    }
            }

            let morphingViewIDs: Set<AnyMorphingViewID> = morphingViews
                .morphingViewsByPages
                .values
                .reduce(into: []) { $0.formUnion($1.ids) }

            Color.clear
                .onChange(of: morphingViewIDs, initial: true) {
                    for (pageID, list) in morphingViews.morphingViewsByPages {
                        store.send(.loadedPages(.element(id: pageID, action: .syncMorphingViewContents(list))))
                    }
                }
        }
    }

    var transitionDefinition: any TransitionDefinition {
        guard !pageProxies.isEmpty else { return .empty }
        return store.transitionProvider.transitions(for: pageProxies, progress: progress)
    }

    func update(sections: SectionCollection) {
        func send(id: AnyPageID, action: PageHostingFeature.Action) {
            store.send(.loadedPages(.element(id: id, action: action)))
        }

        var animationDuration: TimeInterval = 0

        for section in sections {
            guard let timing = section.containerValues.pageTransitionTiming else { continue }
            let transitionAnimation: TransitionAnimation? = progress == .end ? timing : nil
            animationDuration = max(animationDuration, transitionAnimation?.animation.duration ?? 0)

            let animation = transitionAnimation?.createSwiftUIAnimation()

            for subview in section.content {
                guard let ref = subview.containerValues.viewRef else { continue }
                let effects = subview.containerValues.transitionEffects

                func send(_ action: PageHostingFeature.Action) {
                    var transaction = Transaction(animation: animation)
                    transaction.transitionAnimation = transitionAnimation

                    if store.interactiveTransitionProgress != nil, progress != .end {
                        transaction.tracksVelocity = true
                    }
                    store.send(.loadedPages(.element(id: ref.pageID, action: action)), transaction: transaction)
                }

                switch ref {
                case .content:
                    send(.syncTransitionEffects(effects))
                case .wrapper:
                    send(.syncWrapperTransitionEffects(effects))
                case .transitionElement(let id):
                    send(.syncTransitionElementEffects(id.elementID, effects))
                case .morphingView(let id):
                    send(.syncMorphingViewEffects(id.morphingViewID, effects))
                }

                if !subview.containerValues.transitionValues.dict.isEmpty {
                    send(.syncTransitionValues(subview.containerValues.transitionValues))
                }
            }
        }

        for id in pageProxies.ids {
            send(id: id, action: progress == .start ? .transitionDidStart : .transitionDidEnd(animationDuration))
        }
    }
}

extension Transaction {
    @Entry
    var transitionAnimation: TransitionAnimation?
}
