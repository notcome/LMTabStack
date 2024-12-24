import ComposableArchitecture
import SwiftUI
import UIKit

struct PageHostingRoot: View {
    var content: AnyView

    @Environment(PageStore.self)
    private var store

    var body: some View {
        let placement = store.resolvedPlacement
        let transitionToken = store.transition?.transitionToken
        content
            .environment(\.pageVisiblity, store.hidden ? .invisible : .visible)
            .safeAreaPadding(placement.safeAreaInsets)
            .transformAnchorPreference(key: TransitionElementSummary.self, value: .bounds) { summary, pageAnchor in
                summary.transitionToken = transitionToken
                summary.pageAnchor = pageAnchor
            }
            .frame(width: placement.frame.width, height: placement.frame.height)
            .blur(radius: store.transition?.contentValues.blurRadius ?? 0)
            .ignoresSafeArea(.all)
    }
}

struct MorphingViewHostingRoot: View {
    var id: AnyMorphingViewID
    var content: AnyView

    @Environment(PageStore.self)
    private var store

    var body: some View {
        let blurRadius = store.transition?.morphingViews[id: id]?.values.blurRadius ?? 0
        content
            .blur(radius: blurRadius)
            .ignoresSafeArea()
    }
}

final class UXPageHostingViewController: UIViewController {
    let hostingController: UIHostingController<PageHostingRoot>
    let wrapperView = UXAnimationView()
    let contentView = UXAnimationView()

    init(rootView: PageHostingRoot) {
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

    private var morphingViewWrappers: [AnyMorphingViewID: UXAnimationView] = [:]

    func update(morphingViews: IdentifiedArrayOf<MorphingViewState>, transaction: Transaction) {
        for morphingView in morphingViews {
            let id = morphingView.id

            guard let wrapperView = morphingViewWrappers[id] else {
                let wrapperView = UXAnimationView()
                morphingViewWrappers[id] = wrapperView
                self.wrapperView.addSubview(wrapperView)
                bindEdgesToSuperview(wrapperView)
                wrapperView.layer.zPosition = morphingView.zIndex

                let rootView = MorphingViewHostingRoot(id: id, content: morphingView.content)
                let hostingView = _UIHostingView(rootView: rootView)
                hostingView.backgroundColor = .clear
                wrapperView.addSubview(hostingView)
                bindEdgesToSuperview(hostingView)

                hostingView.layoutIfNeeded()
                continue
            }

            wrapperView.layer.zPosition = morphingView.zIndex
            wrapperView.apply(values: morphingView.values, transaction: transaction)
        }
    }

    func resetMorphingViews() {
        morphingViewWrappers.values.forEach {
            $0.removeFromSuperview()
        }
        morphingViewWrappers = [:]
    }
}
