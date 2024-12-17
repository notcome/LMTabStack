import SwiftUI

extension View {
    public func automaticTransition(
        targetPredicate: @escaping (AnyPageID) -> Bool,
        resolve: @escaping (PageProxy, PageProxy, TransitioningPages) -> (some AutomaticTransition)?
    ) -> some View {
        containerValue(\.pageSpecificAutomaticTransitionResolver.lastNode) { sourceID in
            AutomaticTransitionPageToPageResolverNode(
                sourceID: sourceID,
                targetPredicate: targetPredicate,
                resolve: resolve)
        }
    }

    public func automaticTransition<Target: Hashable & Sendable>(
        to targetType: Target.Type = Target.self,
        predicate: @escaping (Target) -> Bool = { _ in true },
        resolve: @escaping (PageProxy, PageProxy, TransitioningPages) -> (some AutomaticTransition)?
    ) -> some View {
        automaticTransition(targetPredicate: { id in
            guard let id = id.base as? Target else { return false }
            return predicate(id)
        }, resolve: resolve)
    }

    public func automaticTransition(
        to targetID: some Hashable & Sendable,
        resolve: @escaping (PageProxy, PageProxy, TransitioningPages) -> (some AutomaticTransition)?
    ) -> some View {
        automaticTransition(
            to: type(of: targetID),
            predicate: { $0 == targetID },
            resolve: resolve)
    }
}

// MARK: - Internals

extension ContainerValues {
    @Entry
    var pageSpecificAutomaticTransitionResolver: PageSpecificAutomaticTransitionResolver = .init()
}

// A little trick to add more nodes.
protocol NodeAppendable {
    associatedtype Node
    var nodes: [Node] { get set }
}

extension NodeAppendable {
    var lastNode: Node? {
        get {
            nodes.last
        }
        set {
            guard let newValue else { return }
            nodes.append(newValue)
        }
    }
}

struct PageSpecificAutomaticTransitionResolver: NodeAppendable {
    var nodes: [(AnyPageID) -> any AutomaticTransitionResolverNode] = []
}

struct AutomaticTransitionResolver {
    var nodes: [any AutomaticTransitionResolverNode] = []

    func resolve(transitioningPages: TransitioningPages) -> AnyAutomaticTransition? {
        var priorityList = nodes.compactMap { node -> (Int, any AutomaticTransitionResolverNode)? in
            guard let priority = node.resolvePriority(transitioningPages: transitioningPages)
            else { return nil }
            return (priority, node)
        }

        priorityList.sort { $0.0 > $1.0 }

        for (_, option) in priorityList {
            if let transition = option.resolve(transitioningPages: transitioningPages) {
                return transition
            }
        }
        return nil
    }
}

protocol AutomaticTransitionResolverNode {
    func resolvePriority(transitioningPages: TransitioningPages) -> Int?
    func resolve(transitioningPages: TransitioningPages) -> AnyAutomaticTransition?
}

struct AutomaticTransitionPageToPageResolverNode: AutomaticTransitionResolverNode {
    var sourceID: AnyPageID
    var targetPredicate: (AnyPageID) -> Bool
    var body: (PageProxy, PageProxy, TransitioningPages) -> AnyAutomaticTransition?

    init(
        sourceID: AnyPageID,
        targetPredicate: @escaping (AnyPageID) -> Bool,
        resolve: @escaping (PageProxy, PageProxy, TransitioningPages) -> (some AutomaticTransition)?
    ) {
        self.sourceID = sourceID
        self.targetPredicate = targetPredicate
        body = { sourcePage, targetPage, allPages in
            guard let transition = resolve(sourcePage, targetPage, allPages) else { return nil }
            return .init(transition)
        }
    }

    func resolvePriority(transitioningPages: TransitioningPages) -> Int? {
        var sourcePage: PageProxy?
        var targetPage: PageProxy?

        let baseCondition = transitioningPages.allSatisfy { page in
            if page.id == sourceID {
                sourcePage = page
            } else if targetPredicate(page.id) {
                targetPage = page
            } else {
                // We might want to think twice about this.
                // Maybe we only allow appearing/disappearing of decoration views.
                return true
            }
            return page.behavior.isAppearing || page.behavior.isDisappearing
        }

        guard baseCondition, let sourcePage, let targetPage else { return nil }
        guard sourcePage.behavior.isAppearing != targetPage.behavior.isAppearing else { return nil }

        return sourcePage.behavior.isAppearing ? 100 : 90
    }

    func resolve(transitioningPages: TransitioningPages) -> AnyAutomaticTransition? {
        let sourcePage = transitioningPages[sourceID]!
        let targetPage = transitioningPages.first { targetPredicate($0.id) }!
        return body(sourcePage, targetPage, transitioningPages)
    }
}
