import SwiftUI

public protocol TabStackLayout {
    func placePages(in context: TabStackLayoutContext, layout: TabStackLayoutProxy)
}

struct EmptyTabStackLayout: TabStackLayout {
    func placePages(in context: TabStackLayoutContext, layout: TabStackLayoutProxy) {}
}

extension EnvironmentValues {
    @Entry
    var tabStackLayout: any TabStackLayout = EmptyTabStackLayout()
}

extension View {
    public func tabStackLayout(_ layout: some TabStackLayout) -> some View {
        environment(\.tabStackLayout, layout)
    }
}

public struct TabStackLayoutContext {
    public let bounds: CGRect
    public let safeAreaInsets: EdgeInsets
    public let keyboardSafeAreaInsets: EdgeInsets
}

public struct PagePlacement: Equatable {
    public var zIndex: Double
    public var frame: CGRect
    public var safeAreaInsets: EdgeInsets
}
