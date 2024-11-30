import ComposableArchitecture

public enum TransitionProgress: Equatable, Sendable {
    case start
    case end
}

public enum PageTransitionBehavior: Equatable {
    case appear(PagePlacement)
    case disappear(PagePlacement)
    case identity(PagePlacement, PagePlacement)
}

@Reducer
struct TabStackFeature {
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored
        @EqualityIgnored
        var pageContents: IdentifiedArrayOf<ViewContent.Page> = []

        var loadedPages: IdentifiedArrayOf<PageHostingFeature.State> = []

        var transitionProgress: TransitionProgress?
        @ObservationStateIgnored
        var transitionReportedStatus: TransitionReportedStatus = .initial
    }

    struct CurrentViewState {
        var animated: Bool
        var layout: LayoutOutput
    }

    enum SyncAction {
        case currentViewState(CurrentViewState)
        case pageContents(IdentifiedArrayOf<ViewContent.Page>)
    }

    enum Action {
        case loadedPages(IdentifiedActionOf<PageHostingFeature>)
        case sync(SyncAction)

        case moveTransitionProgressToEnd
        case cleanUpTransition
    }

    var body: some Reducer<State, Action> {
        Reduce(reduceSelf(state:action:))
            .forEach(\.loadedPages, action: \.loadedPages) {
                PageHostingFeature()
            }
    }

    private func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .sync(.currentViewState(let cvs)):
            let oldVisibleIDs = Set(state.loadedPages.filter { !$0.hidden }.ids)
            let newVisibleIDs = Set(cvs.layout.pages.ids)
            if oldVisibleIDs == newVisibleIDs || oldVisibleIDs.isEmpty {
                state.update(to: cvs.layout)
            } else {
                state.animate(to: cvs.layout)
            }

        case .sync(.pageContents(let pageContents)):
            state.pageContents = pageContents

        case let .loadedPages(.element(id: page, action: .transitionDidStart)):
            return state.transitionDidStart(for: page)

        case let .loadedPages(.element(id: page, action: .transitionDidEnd)):
            return state.transitionDidEnd(for: page)

        case .moveTransitionProgressToEnd:
            state.transitionProgress = .end

        case .cleanUpTransition:
            state.cleanUpTransition()

        default:
            break
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

extension TabStackFeature.State {
    var transitioningPages: Set<AnyPageID> {
        loadedPages.reduce(into: []) {
            guard $1.transitionBehavior != nil else { return }
            $0.insert($1.id)
        }
    }

    func transitioningPagesAllSatisfy(predicate: (PageHostingFeature.State) -> Bool) -> Bool {
        loadedPages
            .filter { $0.transitionBehavior != nil }
            .allSatisfy(predicate)
    }

    mutating func update(to layout: LayoutOutput) {
        for id in loadedPages.ids {
            if let pageLayout = layout.pages[id: id] {
                updateIfNeeded(&loadedPages[id: id]!.placement, to: pageLayout.placement)
                updateIfNeeded(&loadedPages[id: id]!.hidden, to: false)
            } else {
                updateIfNeeded(&loadedPages[id: id]!.hidden, to: true)
            }
        }

        for pageLayout in layout.pages {
            let id = pageLayout.id
            guard loadedPages[id: id] == nil else { continue }
            let loadedPage = PageHostingFeature.State(
                id: id,
                placement: pageLayout.placement,
                hidden: false)
            loadedPages.append(loadedPage)
        }
    }

    mutating func animate(to layout: LayoutOutput) {
        for oldState in loadedPages {
            let id = oldState.id
            if let newState = layout.pages[id: id] {
                if oldState.hidden {
                    loadedPages[id: id]!.hidden = false
                    loadedPages[id: id]!.transitionBehavior = .appear(newState.placement)
                } else {
                    guard oldState.placement != newState.placement else { continue }
                    loadedPages[id: id]!.transitionBehavior = .identity(oldState.placement, newState.placement)
                }
            } else if !oldState.hidden {
                loadedPages[id: id]!.transitionBehavior = .disappear(oldState.placement)
            }
        }

        for newState in layout.pages {
            let id = newState.id
            guard loadedPages[id: id] == nil else { continue }
            let loadedPage = PageHostingFeature.State(
                id: id,
                placement: newState.placement,
                hidden: false,
                transitionBehavior: .appear(newState.placement))
            loadedPages.append(loadedPage)
        }

        guard !transitioningPages.isEmpty else { return }

        for id in transitioningPages {
            loadedPages[id: id]!.transitionEffects = .init()
            loadedPages[id: id]!.wrapperTransitionEffects = .init()
        }

        transitionProgress = .start
    }

    mutating func transitionDidStart(for page: AnyPageID) -> Effect<TabStackFeature.Action> {
        guard transitionReportedStatus != .didStart else { return .none }
        let allDidStart = transitioningPagesAllSatisfy {
            $0.transitionReportedStatus == .didStart
        }
        guard allDidStart else { return .none }
        transitionReportedStatus = .didStart
        return .run { send in
            await send(.moveTransitionProgressToEnd)
        }
    }

    mutating func transitionDidEnd(for page: AnyPageID) -> Effect<TabStackFeature.Action> {
        guard transitionReportedStatus != .didEnd else { return .none }
        let allDidEnd = transitioningPagesAllSatisfy {
            $0.transitionReportedStatus == .didEnd
        }
        guard allDidEnd else { return .none }
        return .run { send in
            do {
                try await Task.sleep(for: .milliseconds(2000))
                await send(.cleanUpTransition)
            } catch {
                print(error)
            }
        }
    }

    mutating func cleanUpTransition() {
        transitionProgress = nil
        transitionReportedStatus = .initial
        for id in loadedPages.ids {
            guard let transitionBehavior = loadedPages[id: id]!.transitionBehavior else { continue }
            loadedPages[id: id]!.cleanUpTransition()

            switch transitionBehavior {
            case .disappear:
                loadedPages[id: id]!.hidden = true
            default:
                updateIfNeeded(&loadedPages[id: id]!.hidden, to: false)
            }
        }
        assert(transitioningPages.isEmpty)
    }
}
