import ComposableArchitecture
import SwiftUI
import UIKit

struct PageHostingRoot: View {
    var content: AnyView

    @Environment(PageStore.self)
    private var store

    @TransitionValueReader(\.blurRadius)
    private var blurRadius

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
            .blur(radius: blurRadius ?? 0)
            .ignoresSafeArea(.all)
    }
}

final class UXPageHostingViewController: UIViewController {
    let hostingController: UIHostingController<PageHostingRoot>
    let wrapperView = UXAnimationView()

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
        wrapperView.addSubview(hostingView)
        bindEdgesToSuperview(wrapperView)
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
}
