import ComposableArchitecture
import SwiftUI

public struct MorphingViewGroup<Content: View>: View {
    public var id: AnyPageID
    public var content: Content

    @Environment(TabStackStore.self)
    private var store

    public init(
        for id: AnyPageID,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.content = content()
    }

    public init(
        for id: some Hashable & Sendable,
        @ViewBuilder content: () -> Content
    ) {
        self.id = AnyPageID(id)
        self.content = content()
    }

    public var body: some View {
        if store.transitionStage != nil {
            let childStore = store.scope(state: \.pages[id: id], action: \.pages[id: id]) as PageStore?
            if childStore != nil {
                Section {
                    content
                }
                .tag(id)
                .environment(childStore)
            } else {
                fatalError("Non-existing page: \(id)")
            }
        }
    }
}

public struct MorphingView<Content: View>: View {
    public var id: AnyMorphingViewID
    public var content: Content

    public init(
        for id: some Hashable & Sendable,
        @ViewBuilder content: () -> Content
    ) {
        self.id = AnyMorphingViewID(id)
        self.content = content()
    }

    public var body: some View {
        content
            .tag(id)
    }
}

public struct MorphingViewsProxy {
    var morphingViewsByPages: [AnyPageID: IdentifiedArrayOf<MorphingViewContent>] = [:]

    static func from(_ sections: SectionCollection) -> Self {
        var proxy = Self()

        for section in sections {
            guard let pageID = section.containerValues.tag(for: AnyPageID.self) else { continue }
            for subview in section.content {
                guard let morphingViewID = subview.containerValues.tag(for: AnyMorphingViewID.self) else { continue }
                let content = MorphingViewContent(
                    id: morphingViewID,
                    content: AnyView(subview),
                    zIndex: subview.containerValues.morphingViewContentZIndex)
                proxy.morphingViewsByPages[pageID, default: []].append(content)
            }
        }

        return proxy
    }

    public func morphingView(pageID: AnyPageID, morphingViewID: some Hashable & Sendable) -> MorphingViewProxy? {
        let morphingViewID = AnyMorphingViewID(morphingViewID)
        guard let views = morphingViewsByPages[pageID],
              views[id: morphingViewID] != nil
        else { return nil }
        return .init(id: .init(pageID: pageID, morphingViewID: morphingViewID))
    }
}

struct MorphingViewContent: Identifiable, Equatable {
    var id: AnyMorphingViewID
    @EqualityIgnored
    var content: AnyView
    var zIndex: Double?
}

extension ContainerValues {
    @Entry
    var morphingViewContentZIndex: Double?
}

public struct MorphingViewProxy: Identifiable {
    public struct ID: Hashable {
        public var pageID: AnyPageID
        public var morphingViewID: AnyMorphingViewID
    }

    public var id: ID
}

extension MorphingViewProxy: View {
    public var body: some View {
        ViewRefView(ref: .morphingView(id))
    }
}

extension View {
    public func morphingViewContentZIndex(_ value: Double) -> some View {
        containerValue(\.morphingViewContentZIndex, value)
    }
}
