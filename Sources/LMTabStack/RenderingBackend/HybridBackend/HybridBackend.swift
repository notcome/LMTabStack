import SwiftUI

struct PageHostingViewHybridBackend {
    var content: AnyView

    @Environment(\.viewTransitionModel)
    private var viewTransitionModel
}

extension PageHostingViewHybridBackend: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UXPageHostingViewController {
        .init(rootView: .init(content: content))
    }

    func updateUIViewController(_ vc: UXPageHostingViewController, context: Context) {
        withTransaction(context.transaction) {
            vc.hostingController.rootView.content = content
        }

        if viewTransitionModel.transitionInProgress {
            vc.wrapperView.apply(values: viewTransitionModel.access(\.self), transaction: context.transaction)
        } else {
            vc.wrapperView.resetAllAnimations()
        }
    }
}
