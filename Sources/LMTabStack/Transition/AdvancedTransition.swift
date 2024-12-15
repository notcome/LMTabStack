import SwiftUI

public protocol AdvancedTransition {
    associatedtype MorphingViews: View
    associatedtype Transitions: View

    @ViewBuilder
    var morphingViews: MorphingViews { get }

    @ViewBuilder
    func transitions(morphingViews: MorphingViewsProxy) -> Transitions
}

extension AdvancedTransition {
    public var morphingViews: some View {
        EmptyView()
    }
}
