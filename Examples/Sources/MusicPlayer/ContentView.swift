import ComposableArchitecture
import LMTabStack
import SwiftUI



@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        @Presents
        var session: SessionFeature.State?
    }

    enum Action {
        case session(PresentationAction<SessionFeature.Action>)

        case newSession
    }

    var body: some Reducer<State, Action> {
        Reduce(reduceSelf(state:action:))
            .ifLet(\.$session, action: \.session) {
                SessionFeature()
            }
    }
}

private extension RootFeature {
    func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .newSession:
            state.session = .init(session: .init())

        default:
            break
        }
        return .none
    }
}

@MainActor
func makeRootStore() -> StoreOf<RootFeature> {
    Store(initialState: RootFeature.State()) {
        RootFeature()
    }
}

struct HomePage: View {
    var store: StoreOf<RootFeature>

    var body: some View {
        Page(id: "Home") {
            VStack {
                Button {
                    store.send(.newSession)
                } label: {
                    Text("New Session")
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}
public struct ContentView: View {
    public init() {}

    @State
    private var store = makeRootStore()

    public var body: some View {
        PageFlow {
            HomePage(store: store)

            if let sessionStore = store.scope(state: \.session, action: \.session.presented) {
                SessionPages(store: sessionStore)
            }
        }
        .environment(\.pageFlowLayout, FullScreenLayout())
        .tint(.black)
    }
}
