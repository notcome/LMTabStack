import SwiftUI

public struct TabStack<Value: Hashable & Sendable, Content: View>: View {
    var value: Value
    var content: Content

    public init(
        _ value: Value,
        @ViewBuilder content: () -> Content
    ) {
        self.value = value
        self.content = content()
    }

    public var body: some View {
        Section {
            content
        }
        .tag(AnyTabID(value))
    }
}
