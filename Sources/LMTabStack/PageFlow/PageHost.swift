import SwiftUI

@MainActor
public protocol PageHost: DynamicProperty {
    associatedtype Content: View

    @ViewBuilder
    func body(page: AnyView, geometryProxy: GeometryProxy) -> Content
}

private struct EmptyPageHost: PageHost {
    func body(page: AnyView, geometryProxy: GeometryProxy) -> some View {
        page
    }
}

extension EnvironmentValues {
    @Entry
    public var pageHost: any PageHost = EmptyPageHost()
}

private struct PageHostView<Host: PageHost>: View {
    var host: Host
    var page: AnyView
    var geometryProxy: GeometryProxy

    var body: some View {
        host.body(page: page, geometryProxy: geometryProxy)
    }
}

extension PageHost {
    func eraseToView(page: AnyView, geometryProxy: GeometryProxy) -> AnyView {
        let typed = PageHostView(host: self, page: page, geometryProxy: geometryProxy)
        return AnyView(typed)
    }
}
