import SwiftUI

public struct PageFlow<Content: View>: View {
    public var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.pageFlowLayout)
    private var pageFlowLayout

    public var body: some View {
        Group(sections: content) { sections in
            pageFlowLayout.eraseToView(sections: sections)
        }
    }
}

@MainActor
public protocol PageFlowLayout: DynamicProperty {
    associatedtype Content: View

    @ViewBuilder
    func body(sections: SectionCollection) -> Content
}

private struct EmptyPageFlowLayout: PageFlowLayout {
    func body(sections: SectionCollection) -> some View {
        Text("Empty page flow layout")
    }
}

extension EnvironmentValues {
    @Entry
    public var pageFlowLayout: any PageFlowLayout = EmptyPageFlowLayout()
}

private struct PageFlowLayoutView<Layout: PageFlowLayout>: View {
    var layout: Layout
    var sections: SectionCollection

    var body: some View {
        layout.body(sections: sections)
    }
}

private extension PageFlowLayout {
    func eraseToView(sections: SectionCollection) -> AnyView {
        let typed = PageFlowLayoutView(layout: self, sections: sections)
        return AnyView(typed)
    }
}
