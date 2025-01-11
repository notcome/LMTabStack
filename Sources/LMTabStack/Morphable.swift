import SwiftUI

private struct _Morphable: ViewModifier {
    var id: AnyMorphableID

    @Environment(\.pageCoordinator)
    private var pageCoordinator

    func body(content: Content) -> some View {
        content
            .modifier(MorphableModifier())
            .environment(\.viewTransitionModel, viewTransitionModel)
            .anchorPreference(key: TransitionElementSummary.self, value: .bounds) { anchor in
                var summary = TransitionElementSummary()
                summary.morphables[id] = anchor
                return summary
            }
    }

    var viewTransitionModel: ViewTransitionModel {
        pageCoordinator?.morphableTransitionModel(for: id) ?? EmptyViewTransitionModel()
    }
}

extension View {
    public func morphable<ID: Hashable & Sendable>(id: ID) -> some View {
        modifier(_Morphable(id: AnyMorphableID(id)))
    }
}
