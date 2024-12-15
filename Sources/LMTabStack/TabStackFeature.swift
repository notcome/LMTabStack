import ComposableArchitecture
import SwiftUI

struct GeneratedPage: Identifiable, Equatable {
    var id: AnyPageID
    @EqualityIgnored
    var content: AnyView
    var placement: PagePlacement?
}

typealias GeneratedPages = IdentifiedArrayOf<GeneratedPage>

@Reducer
struct TabStackFeature {
    @ObservableState
    struct State: Equatable {
        var pages: IdentifiedArrayOf<PageFeature.State> = []

        var transitionStage: TransitionStage?
        @ObservationStateIgnored
        var pendingUpdate: GeneratedPages?
    }

    enum Action {
        case pages(IdentifiedActionOf<PageFeature>)
        case update(IdentifiedArrayOf<GeneratedPage>, TransitionResolver?)

        case transitionDidCommit(token: Int, animationDuration: TimeInterval?)
        case transitionDidComplete
    }

    var body: some Reducer<State, Action> {
        Reduce(reduceSelf(state:action:))
            .forEach(\.pages, action: \.pages) {
                PageFeature()
            }
    }

    private func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pages(.element(id: id, action: .delegate(action))):
            return state.handle(page: id, delegateAction: action)

        case .pages:
            break

        case let .update(newPages, resolver):
            guard state.transitionStage == nil else {
                state.pendingUpdate = newPages
                break
            }

            guard !state.pages.isEmpty, let resolver else {
                state.update(to: newPages)
                break
            }

            let behaviors = state.prepareForTransitions(newPages: newPages)
            guard !behaviors.isEmpty else { break }
            state.transitionStage = .unresolved(.init(target: newPages, resolver: resolver))
            state.resolveTransition()

        case let .transitionDidCommit(token: token, animationDuration: animationDuration):
            return state.transitionDidCommit(token: token, animationDuration: animationDuration)

        case .transitionDidComplete:
            state.cleanUpTransition()
        }
        return .none
    }
}

typealias TabStackStore = StoreOf<TabStackFeature>

@MainActor
func createTabStackStore() -> TabStackStore {
    return .init(initialState: .init()) {
        TabStackFeature()
    }
}

private extension TabStackFeature.State {
    mutating func update(to newPages: GeneratedPages) {
        for i in pages.indices {
            let id = pages[i].id
            guard let newPage = newPages[id: id] else { continue }
            pages[i].content = newPage.content

            if let placement = newPage.placement {
                pages[i].hidden = false
                pages[i].placement = placement
            } else {
                pages[i].hidden = true
            }
        }

        for newPage in newPages  {
            let id = newPage.id
            guard let placement = newPage.placement,
                  pages[id: newPage.id] == nil
            else { continue }
            pages.append(.init(id: id, content: newPage.content, placement: placement))
        }

        pages.removeAll { newPages[id: $0.id] == nil }
    }

    mutating func prepareForTransitions(newPages: GeneratedPages) -> [AnyPageID: PageTransitionBehavior] {
        var behaviors: [AnyPageID: PageTransitionBehavior] = [:]

        for oldPage in pages {
            let id = oldPage.id

            guard let newPage = newPages[id: id] else {
                behaviors[id] = .disappear(oldPage.placement)
                continue
            }
            pages[id: id]!.content = newPage.content

            guard let newPlacement = newPage.placement else {
                behaviors[id] = .disappear(oldPage.placement)
                continue
            }

            if oldPage.hidden {
                pages[id: id]!.hidden = false
                behaviors[id] = .appear(newPlacement)
            } else if oldPage.placement != newPlacement {
                behaviors[id] = .change(oldPage.placement, newPlacement)
            }
        }

        for newPage in newPages {
            let id = newPage.id
            guard let placement = newPage.placement,
                  pages[id: id] == nil
            else { continue }
            behaviors[id] = .appear(placement)
            pages.append(.init(id: id, content: newPage.content, placement: placement))
        }

        for (id, behavior) in behaviors {
            pages[id: id]!.transitionBehavior = behavior
        }

        return behaviors
    }

    mutating func resolveTransition() {
        guard case .unresolved(let state) = transitionStage else { fatalError() }

        guard let transitioningPages = TransitioningPages(pages: pages) else { return }
        switch state.resolver {
        case .automatic(let f):
            var transition = f(transitioningPages)
            transition.progress = .start
            transitionStage = .resolved(.init(transition: .automatic(transition), target: state.target))
        case .interactive(let f):
            let transition = f(transitioningPages)
            precondition(!transition.isComplete)
            transitionStage = .resolved(.init(transition: .interactive(transition), target: state.target))
        }

        for page in transitioningPages {
            pages[id: page.id]!.transition = .init(
                pageState: page.state,
                behavior: page.behavior)
        }
    }

    var resolvedTransition: TransitionResolvedState! {
        get {
            guard case .resolved(let state) = transitionStage else { return nil }
            return state
        }
        set {
            guard resolvedTransition != nil else { fatalError() }
            transitionStage = .resolved(newValue)
        }
    }

    mutating func handle(page id: AnyPageID, delegateAction action: PageFeature.DelegateAction) -> Effect<TabStackFeature.Action> {
        switch action {
        case .pageDidLoad:
            guard case .unresolved = transitionStage else { break }
            resolveTransition()

        case .pageTransitionTokenDidUpdate:
            guard resolvedTransition != nil else { break }
            let target = resolvedTransition.committedTransitionToken
            let allAligned = pages.allSatisfy { page in
                guard let token = page.transition?.transitionToken else { return true }
                let pageAligned = token == page.mountedLayout?.transitionToken
                return pageAligned && token == target
            }
            guard allAligned else { break }

            if resolvedTransition.waitingTarget == .waitingForStartToRender,
               case .automatic(var transition) = resolvedTransition.transition
            {
                transition.progress = .end
                resolvedTransition.transition = .automatic(transition)
            }
        }
        return .none
    }

    mutating func transitionDidCommit(token: Int, animationDuration: TimeInterval?) -> Effect<TabStackFeature.Action> {
        guard resolvedTransition != nil else { fatalError() }
        // Check if we have already processed it.
        guard token > (resolvedTransition.committedTransitionToken ?? -1) else { return .none }
        resolvedTransition.committedTransitionToken = token

        switch resolvedTransition.transition {
        case .automatic(let t):
            guard t.progress == .end else {
                resolvedTransition.waitingTarget = .waitingForStartToRender
                break
            }

            resolvedTransition.waitingTarget = .waitingForAnimation
            let duration = Duration.milliseconds(round((animationDuration ?? 0) * 1000))
            return .run { send in
                do {
                    try await Task.sleep(for: duration)
                    await send(.transitionDidComplete)
                } catch {
                    logger.error("Transition animation task is cancelled.")
                }
            }

        case .interactive:
            fatalError("Unimplemented")
        }

        for i in pages.indices where pages[i].transition != nil {
            pages[i].transition?.transitionToken = token
        }
        return .none
    }

    mutating func cleanUpTransition() {
        defer {
            pendingUpdate = nil
            transitionStage = nil
        }

        let finalTarget = pendingUpdate ?? resolvedTransition.target

        for newPage in finalTarget {
            let id = newPage.id
            guard var page = pages[id: id] else {
                precondition(newPage.placement == nil)
                continue
            }
            if let placement = newPage.placement {
                page.placement = placement
                page.hidden = false
            } else {
                page.hidden = true
            }
            pages[id: id]! = page
        }
        for i in pages.indices where pages[i].transition != nil {
            pages[i].transition = nil
            pages[i].transitionBehavior = nil
        }

        pages.removeAll { finalTarget[id: $0.id] == nil }
    }
}
