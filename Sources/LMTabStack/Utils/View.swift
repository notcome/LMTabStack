import SwiftUI

extension View {
    nonisolated func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
