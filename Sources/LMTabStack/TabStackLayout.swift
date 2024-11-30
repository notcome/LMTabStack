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
}

public struct PagePlacement: Equatable {
    public var zIndex: Double
    public var frame: CGRect
    public var safeAreaInsets: EdgeInsets
}

struct AbsolutePlacementModifier: ViewModifier {
    var frame: CGRect
    var parentBounds: CGRect

    func body(content: Content) -> some View {
        content
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: parentBounds.width, height: parentBounds.height, alignment: .topLeading)
    }
}

extension View {
    func absolutePlacement(frame: CGRect, parentBounds: CGRect) -> some View {
        modifier(AbsolutePlacementModifier(frame: frame, parentBounds: parentBounds))
    }
}

