import IdentifiedCollections
import SwiftUI

public struct TabStackTabItem<Tab: Hashable>: Identifiable {
    public var id: Tab
    public var label: AnyView
}

private struct PlacementView: View {
    @Environment(TabStackStore.self)
    private var store

    var body: some View {
        GeometryReader { proxy in
            ForEach(store.pages) { page in
                page.content
                    .zIndex(page.resolvedPlacement.zIndex)
            }
        }
    }
}

public struct TabStackView<Tab: Hashable & Sendable, Content: View>: View {
    public typealias TabItem = TabStackTabItem<Tab>

    @Binding
    var selection: Tab
    var content: Content

    @State
    private var store = createTabStackStore()

    public init(
        selection: Binding<Tab>,
        @ViewBuilder content: () -> Content
    ) {
        _selection = selection
        self.content = content()
    }

    public var body: some View {
        PlacementView()
            .background {
                Group(sections: content) { sections in
                    PageGenerator(viewContent: .from(sections, selectedTab: selection))
                }
            }
            .background {
                TransitionGenerator()
            }
            .environment(store)
    }
}

extension GeometryProxy {
    var boundsWithoutSafeAreaInsets: CGRect {
        var bounds = CGRect(origin: .zero, size: size)
        bounds.size.width += safeAreaInsets.leading + safeAreaInsets.trailing
        bounds.size.height += safeAreaInsets.top + safeAreaInsets.bottom
        return bounds
    }
}


public enum TabStackRenderingMode {
    /// Renders everything using pure SwiftUI.
    case pure
    /// Wraps certain subviews in a native hosting view provided by UIKit/AppKit.
    /// Some transitions will be rendered via Core Animation.
    ///
    /// As of iOS 18, this rendering mode is required to run animations at 120Hz on iPhones with ProMotion support.
    /// This should be more energy efficient too, as `CAAnimation`s are generally cheaper than SwiftUI’s native animations.
    case hybrid
}

public enum PageVisiblity {
    case visible
    case invisible
}

extension EnvironmentValues {
    @Entry
    public var tabStackRenderingMode: TabStackRenderingMode = .pure

    @Entry
    public var pageVisiblity: PageVisiblity = .visible
}

private struct PageVisiblityChangeHook: ViewModifier {
    var target: PageVisiblity
    var action: () -> Void

    @Environment(\.pageVisiblity)
    private var pageVisiblity

    func body(content: Content) -> some View {
        content
            .onChange(of: pageVisiblity, initial: true) {
                guard target == pageVisiblity else { return }
                action()
            }
    }
}

extension View {
    public func onPageAppear(action: @escaping () -> Void) -> some View {
        modifier(PageVisiblityChangeHook(target: .visible, action: action))
    }

    public func onPageDisappear(action: @escaping () -> Void) -> some View {
        modifier(PageVisiblityChangeHook(target: .invisible, action: action))
    }
}
