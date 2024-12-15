import SwiftUI

struct PageHostingViewHybridBackend {
    var content: AnyView

    @Environment(PageStore.self)
    private var store
}

extension PageHostingViewHybridBackend: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UXPageHostingViewController {
        .init(rootView: .init(content: content))
    }

    func updateUIViewController(_ vc: UXPageHostingViewController, context: Context) {
        withTransaction(context.transaction) {
            vc.hostingController.rootView.content = content
        }

        if let transition = store.transition {
            vc.contentView.apply(effects: transition.contentEffects, transaction: context.transaction)
            vc.update(morphingViews: transition.morphingViews, transaction: context.transaction)
            vc.wrapperView.apply(effects: transition.wrapperEffects, transaction: context.transaction)
        } else {
            vc.contentView.resetAllAnimations()
            vc.resetMorphingViews()
            vc.wrapperView.resetAllAnimations()
        }
    }
}
