import ComposableArchitecture
import SwiftUI

extension ContainerValues {
    @Entry
    var pageContent: AnyView?
}


public struct Page<ID: Hashable & Sendable, Content: View>: View {
    var id: ID
    var content: Content

    @Environment(TabStackStore.self)
    private var store

    public init(
        id: ID,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.content = content()
    }

    public var body: some View {
        let id = AnyPageID(id)
        GeometryReader { _ in
            let childStore = store.scope(state: \.loadedPages[id: id], action: \.loadedPages[id: id]) as PageHostingStore?
            if let childStore {
                PageHostingView(
                    store: childStore,
                    content: AnyView(content),
                    transitionProgress: store.transitionProgress
                )
                .environment(childStore)
            }
        }
        .tag(id)
        .id(id)
    }
}

struct PageHostingView: View {
    var store: StoreOf<PageHostingFeature>
    var content: AnyView
    var transitionProgress: TransitionProgress?

    var id: AnyPageID { store.id }

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    var body: some View {
        let placement = store.state.placement(for: transitionProgress)
        let opacity = store.state.opacity(for: transitionProgress)
        let frame = placement.frame

        Group {
            switch renderingMode {
            case .pure:
                _PageHostingPureBackend(
                    content: content,
                    transitionProgress: transitionProgress,
                    safeAreaInsets: placement.safeAreaInsets
                )
            case .hybrid:
                _PageHostingHybridBackend(
                    content: content,
                    transitionProgress: transitionProgress)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
        .opacity(opacity)
        .onPreferenceChange(TransitionElementSummary.self) { summary in
            let _ = print("sync transition elements", summary.elements.keys.map(\.base))
            store.send(.syncTransitionElements(summary))
        }
        .environment(store)
        .ignoresSafeArea(.all)
    }
}

// MARK: Pure Backend

private struct _PageHostingPureBackend: View {
    var content: AnyView
    var transitionProgress: TransitionProgress?
    var safeAreaInsets: EdgeInsets

    @Environment(StoreOf<PageHostingFeature>.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                        summary.pageAnchor = pageAnchor
                    }
                    .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
                    .safeAreaPadding(safeAreaInsets)
                    .modifier(store.transitionEffects ?? .init())
                    .zIndex(0)

                ForEach(store.morphingViewContents) { content in
                    content.content
                        .modifier(store.morphingViewEffects[content.id] ?? .init())
                        .zIndex(content.zIndex ?? 0)

                }
            }
            .modifier(store.wrapperTransitionEffects ?? .init())
        }
    }
}

// MARK: Hybrid Backend

private struct _PageHostingRootView: View {
    var content: AnyView
    var transitionProgress: TransitionProgress?

    @Environment(StoreOf<PageHostingFeature>.self)
    private var store

    var body: some View {
        let state = store.state
        let placement = state.placement(for: transitionProgress)

        content
            .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
            .safeAreaPadding(placement.safeAreaInsets)
            .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                summary.pageAnchor = pageAnchor
            }
            .blur(radius: store.transitionEffects?.blurRadius ?? 0)
            .ignoresSafeArea(.all)
    }
}

private struct _MorphingHostingRootView: View {
    var content: AnyView
    var effects: TransitionEffects?

    var body: some View {
        content
            .blur(radius: effects?.blurRadius ?? 0)
            .ignoresSafeArea()
    }
}

private final class _PageHostingViewController: UIViewController {
    let hostingController: UIHostingController<_PageHostingRootView>
    let wrapperView = _AnimatableView()
    let contentView = _AnimatableView()

    init(rootView: _PageHostingRootView) {
        hostingController = .init(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        view.addSubview(wrapperView)
        wrapperView.addSubview(contentView)
        contentView.addSubview(hostingView)

        bindEdgesToSuperview(wrapperView)
        bindEdgesToSuperview(contentView)
        bindEdgesToSuperview(hostingView)
    }

    private var hostingView: UIView {
        hostingController.view
    }

    private func bindEdgesToSuperview(_ view: UIView) {
        let superview = view.superview!

        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            view.topAnchor.constraint(equalTo: superview.topAnchor),
            view.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
        ])
    }

    private var morphingViews: [AnyMorphingViewID: _AnimatableView] = [:]
    private var morphingHostingViews: [AnyMorphingViewID: _UIHostingView<_MorphingHostingRootView>] = [:]

    func updateMorphingViews(
        _ list: IdentifiedArrayOf<MorphingViewContent>,
        dict: [AnyMorphingViewID: TransitionEffects],
        transaction: Transaction
    ) {
        for (id, view) in morphingViews where list[id: id] == nil {
            view.removeFromSuperview()
            morphingViews[id] = nil
        }
        for content in list {
            if let morphingView = morphingViews[content.id] {
                morphingView.layer.zPosition = content.zIndex ?? 0
                continue
            }

            let morphingView = _AnimatableView()
            morphingViews[content.id] = morphingView
            wrapperView.addSubview(morphingView)
            bindEdgesToSuperview(morphingView)
            morphingView.layer.zPosition = content.zIndex ?? 0

            let hostingView = _UIHostingView(rootView: _MorphingHostingRootView(
                content: content.content,
                effects: dict[content.id]
            ))
            morphingHostingViews[content.id] = hostingView

            hostingView.backgroundColor = .clear
            morphingView.addSubview(hostingView)
            bindEdgesToSuperview(hostingView)
        }

        for (id, view) in morphingViews {
            let effects = dict[id]
            view.apply(effects: effects ?? .init(), createCAAnimation: transaction.createCAAnimation)
            withTransaction(transaction) {
                morphingHostingViews[id]!.rootView.effects = effects
            }
        }
    }
}

private struct _PageHostingViewControllerRepresentable: UIViewControllerRepresentable {
    var content: AnyView
    var transitionProgress: TransitionProgress?

    @Environment(StoreOf<PageHostingFeature>.self)
    private var store

    func makeUIViewController(context: Context) -> _PageHostingViewController {
        .init(rootView: .init(content: content, transitionProgress: transitionProgress))
    }

    func updateUIViewController(_ vc: _PageHostingViewController, context: Context) {
        withTransaction(context.transaction) {
            vc.hostingController.rootView.content = content
            vc.hostingController.rootView.transitionProgress = transitionProgress
        }

        vc.contentView.apply(effects: store.transitionEffects, createCAAnimation: context.transaction.createCAAnimation)

        vc.updateMorphingViews(
            store.morphingViewContents,
            dict: store.morphingViewEffects,
            transaction: context.transaction)

        vc.wrapperView.apply(effects: store.wrapperTransitionEffects, createCAAnimation: context.transaction.createCAAnimation)
    }
}


private struct _PageHostingHybridBackend: View {
    var content: AnyView
    var transitionProgress: TransitionProgress?

    var body: some View {
        _PageHostingViewControllerRepresentable(content: content, transitionProgress: transitionProgress)
    }
}

final class _AnimatableView: UIView {
    private enum KeyPathState {
        case constant(Double)
        case animating(Double, Double)
    }

    private var keyPathStates: [String: KeyPathState] = [:]

    func resetAllAnimations() {
        layer.removeAllAnimations()
        keyPathStates = [:]
    }

    private func addConstantAnimation(keyPath: String, value: Double) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = value
        animation.toValue = value
        animation.speed = 0
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .constant(value)
    }

    private func addAnimation(_ animation: CABasicAnimation, keyPath: String, from oldValue: Double, to newValue: Double) {
        animation.preferredFrameRateRange = .init(minimum: 60, maximum: 120, preferred: 120)
        animation.fromValue = oldValue
        animation.toValue = newValue
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .animating(oldValue, newValue)
    }

    private func update(keyPath: String, to newValue: Double, createCAAnimation: (() -> CABasicAnimation)?) {
        guard let state = keyPathStates[keyPath] else {
            assert(createCAAnimation == nil)
            addConstantAnimation(keyPath: keyPath, value: newValue)
            return
        }

        switch state {
        case let .constant(oldValue):
            guard oldValue != newValue else { return }
            guard let createCAAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue)
                return
            }
            addAnimation(createCAAnimation(), keyPath: keyPath, from: oldValue, to: newValue)

        case let .animating(oldValue, currentNewValue):
            guard let createCAAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue)
                return
            }
            guard currentNewValue != newValue else { return }
            addAnimation(createCAAnimation(), keyPath: keyPath, from: oldValue, to: newValue)
        }
    }

    func apply(effects: TransitionEffects?, createCAAnimation: (() -> CABasicAnimation)?) {
        guard let effects else {
            resetAllAnimations()
            return
        }

        if let opacity = effects.opacity {
            update(keyPath: "opacity", to: opacity, createCAAnimation: createCAAnimation)
        }
        if let scaleX = effects.scaleX {
            update(keyPath: "transform.scale.x", to: scaleX, createCAAnimation: createCAAnimation)
        }
        if let scaleY = effects.scaleY {
            update(keyPath: "transform.scale.y", to: scaleY, createCAAnimation: createCAAnimation)
        }
        if let offsetX = effects.offsetX {
            update(keyPath: "transform.translation.x", to: offsetX, createCAAnimation: createCAAnimation)
        }
        if let offsetY = effects.offsetY {
            update(keyPath: "transform.translation.y", to: offsetY, createCAAnimation: createCAAnimation)
        }
    }
}
