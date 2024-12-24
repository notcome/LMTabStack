import SwiftUI

public protocol AdvancedTransition {
    associatedtype Transitions: View

    @ViewBuilder
    var transitions: Transitions { get }
}
