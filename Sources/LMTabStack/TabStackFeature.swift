import ComposableArchitecture
import Foundation

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
        @ObservationStateIgnored
        var activePages: Set<AnyPageID> = []

        var loadedPages: IdentifiedArrayOf<PageHostingFeature.State> = []

        var transitionProgress: TransitionProgress?

        @ObservationStateIgnored
        @EqualityIgnored
        private var _transitionProvider: any TransitionProvider = EmptyTransitionProvider()

        var interactiveTransitionProgress: InteractiveTransitionProgress?
        var transitionUpdateToken: Int = 0
        var transitionProvider: any TransitionProvider {
            get {
                _$observationRegistrar.access(self, keyPath: \.transitionProvider)
                return _transitionProvider
            }
            set {
                _$observationRegistrar.mutate(
                    self,
                    keyPath: \.transitionProvider,
                    &_transitionProvider,
                    newValue,
                    { _, _ in false }
                )
            }
        }

        @ObservationStateIgnored
        var transitionReportedStatus: TransitionReportedStatus = .initial
    }

    struct CurrentViewState {
        var interactiveTransitionProgress: InteractiveTransitionProgress?
        var transitionProvider: (any TransitionProvider)?
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

        case refreshTransition
        case completeInteractiveTransition
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
            guard let provider = cvs.transitionProvider else {
                state.update(to: cvs.layout)
                break
            }
            let oldVisibleIDs = Set(state.loadedPages.filter { !$0.hidden }.ids)
            guard !oldVisibleIDs.isEmpty else {
                state.update(to: cvs.layout)
                break
            }
            let newVisibleIDs = Set(cvs.layout.pages.ids)
            guard oldVisibleIDs != newVisibleIDs else {
                state.update(to: cvs.layout)
                break
            }

            state.interactiveTransitionProgress = cvs.interactiveTransitionProgress
            state.transitionProvider = provider
            state.animate(to: cvs.layout)

        case .sync(.pageContents(let pageContents)):
            for page in pageContents {
                state.pageContents.append(page)
            }
            state.activePages = Set(pageContents.ids)

        case let .loadedPages(.element(id: page, action: .transitionDidStart)):
            return state.transitionDidStart(for: page)

        case let .loadedPages(.element(id: page, action: .transitionDidEnd)):
            return state.transitionDidEnd(for: page)

        case .moveTransitionProgressToEnd:
            state.transitionProgress = .end

        case .cleanUpTransition:
            state.cleanUpTransition()
            state.transitionProvider = EmptyTransitionProvider()

        case .refreshTransition:
            state.transitionUpdateToken += 1
        case .completeInteractiveTransition:
            state.transitionProgress = .end

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
                if case .disappear = oldState.transitionBehavior {
                    // The semantics of running this function twice for interactive transition cancellation is unclear.
                    // This if branch is a dirty workaround for now.
                    loadedPages[id: id]!.transitionBehavior = .appear(newState.placement)
                } else if oldState.hidden {
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

        if interactiveTransitionProgress == .end {
            transitionProgress = .end
            return
        }

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

        guard interactiveTransitionProgress == nil else {
            print("This is an interactive transition so we do nothing")
            return .none
        }

        return .run { send in
            await send(.moveTransitionProgressToEnd)
        }
    }

    mutating func transitionDidEnd(for page: AnyPageID) -> Effect<TabStackFeature.Action> {
        guard transitionReportedStatus != .didEnd else { return .none }
        let allDidEnd = transitioningPagesAllSatisfy {
            $0.transitionReportedStatus == .didEnd
        }
        let duration: TimeInterval = loadedPages.reduce(0) {
            max($0, $1.transitionDuration)
        }

        guard allDidEnd else { return .none }
        return .run { send in
            do {
                try await Task.sleep(for: .milliseconds(Int(ceil(duration * 1000))))
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

        interactiveTransitionProgress = nil
        transitionUpdateToken = 0

        logger.trace("Transition did complete")

        loadedPages.removeAll { [activePages] in
            !activePages.contains($0.id)
        }
        pageContents.removeAll { [activePages] in
            !activePages.contains($0.id)
        }
    }
}
