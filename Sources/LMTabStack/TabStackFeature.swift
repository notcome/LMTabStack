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

        case moveTransitionToEnd
        case transitionStartDidCommit
        case transitionEndDidCommit(TimeInterval)
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
        case .pages(.element(id: _, action: .delegate(.pageDidLoad))):
            guard case .unresolved = state.transitionStage else { break }
            state.resolveTransition()

        case .pages:
            break

        case let .update(pages, resolver):
            guard state.transitionStage == nil else {
                state.pendingUpdate = pages
                break
            }

            guard !state.pages.isEmpty, let resolver else {
                for page in pages {
                    let id = page.id
                    if var current = state.pages[id: id] {
                        current.content = page.content
                        if let placement = page.placement {
                            current.hidden = false
                            current.placement = placement
                        } else {
                            current.hidden = true
                        }
                        state.pages[id: id] = current
                    } else if let placement = page.placement {
                        state.pages.append(.init(id: id, content: page.content, placement: placement))
                    }
                }
                state.pages.removeAll { pages[id: $0.id] == nil }
                break
            }

            let behaviors = state.apply(to: pages)
            guard !behaviors.isEmpty else { break }
            state.transitionStage = .unresolved(.init(target: pages, resolver: resolver))
            state.resolveTransition()

        case .moveTransitionToEnd:
            guard case .resolved(var resolved) = state.transitionStage,
                  case .automatic(var transition) = resolved.transition,
                  transition.progress == .start
            else { break }
            transition.progress = .end
            resolved.transition = .automatic(transition)
            state.transitionStage = .resolved(resolved)

        case .transitionStartDidCommit:
            guard case .resolved(let resolved) = state.transitionStage else { fatalError() }
            guard case .automatic(let transition) = resolved.transition,
                  transition.progress == .start
            else { break }
            return .run { send in
//                try? await Task.sleep(for: .milliseconds(1000))
                await send(.moveTransitionToEnd)
            }

        case .transitionEndDidCommit(let t):
            guard case .resolved(var resolved) = state.transitionStage else { fatalError() }
            guard !resolved.sleepingForAnimation else { break }
            resolved.sleepingForAnimation = true
            state.transitionStage = .resolved(resolved)
            let duration = Duration.milliseconds(round(t * 1000))
            return .run { send in
                do {
                    try await Task.sleep(for: duration)
                    await send(.transitionDidComplete)
                } catch {
                    logger.error("Transition animation task is cancelled.")
                }
            }

        case .transitionDidComplete:
            guard case .resolved(let resolved) = state.transitionStage else { fatalError() }
            state.transitionStage = nil

            let finalTarget = state.pendingUpdate ?? resolved.target
            state.pendingUpdate = nil

            for newPage in finalTarget {
                let id = newPage.id
                guard var page = state.pages[id: id] else {
                    precondition(newPage.placement == nil)
                    continue
                }
                if let placement = newPage.placement {
                    page.placement = placement
                    page.hidden = false
                } else {
                    page.hidden = true
                }
                state.pages[id: id]! = page
            }
            for i in state.pages.indices {
                guard state.pages[i].transition != nil else { continue }
                state.pages[i].transition = nil
                state.pages[i].transitionBehavior = nil
            }

            state.pages.removeAll {
                resolved.target[id: $0.id] == nil
            }
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
    mutating func apply(to newPages: GeneratedPages) -> [AnyPageID: PageTransitionBehavior] {
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

        for page in transitioningPages.transitioningPages {
            pages[id: page.id]!.transition = .init(pageState: page, behavior: page.transitionBehavior!)
        }
    }
}
