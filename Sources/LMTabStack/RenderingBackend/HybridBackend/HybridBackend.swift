import SwiftUI

struct PageHostingViewHybridBackend {
    var content: AnyView

    @Environment(PageStore.self)
    private var store

    @Environment(TransitionValuesStore.self)
    private var transitionValues
}

extension PageHostingViewHybridBackend: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UXPageHostingViewController {
        .init(rootView: .init(content: content))
    }

    func updateUIViewController(_ vc: UXPageHostingViewController, context: Context) {
        withTransaction(context.transaction) {
            vc.hostingController.rootView.content = content
        }

        if !transitionValues.isEmpty {
            vc.wrapperView.apply(values: transitionValues.state, transaction: context.transaction)
        } else {
            vc.wrapperView.resetAllAnimations()
        }
    }
}
