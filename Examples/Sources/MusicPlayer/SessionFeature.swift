import ComposableArchitecture
import LMTabStack
import SwiftUI

enum SessionKind: Hashable {
    case good
    case neutral
    case bad

    var color: Color {
        switch self {
        case .good:
            .pink
        case .neutral:
            .green
        case .bad:
            .white
        }
    }
}

@ObservableState
struct Session: Equatable, Identifiable {
    var kind: SessionKind = .good
    var id: UUID = UUID()

    var startTime: Date = .now
    var endTime: Date?
    var totalTime: TimeInterval = 15

    var deadline: Date {
        Date(timeInterval: totalTime, since: startTime)
    }

    var isDone: Bool {
        endTime != nil
    }

    mutating func stop() {
        endTime = .now
    }

    mutating func addTime(_ t: TimeInterval) {
        let now = Date.now
        totalTime = now.timeIntervalSince(startTime) + t
    }

    func displayTime(now: Date) -> String {
        let t = Int(round(max(0, totalTime - now.timeIntervalSince(startTime))))
        let mm = t / 60
        let ss = t % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}

@Reducer
struct SessionFeature {
    @Dependency(\.dismiss)
    private var dismiss

    @ObservableState
    struct State: Equatable {
        var session: Session
        var showsTimer: Bool
        var showsAddTime: Bool

        init(session: Session) {
            self.session = session
            showsTimer = !session.isDone
            showsAddTime = session.deadline <= .now
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)

        case dismiss
    }

    var body: some Reducer<State, Action> {
        Reduce(reduceSelf(state:action:))
        BindingReducer()
    }
}

private extension SessionFeature {
    func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .dismiss:
            return .run { _ in
                await dismiss()
            }

        default:
            break
        }
        return .none
    }
}

struct SessionTimerView: View {
    @Bindable
    var store: StoreOf<SessionFeature>

    var body: some View {
        VStack {
            HStack {
                Button {
                    store.send(.dismiss)
                } label: {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(store.session.kind.color)
                }
                Spacer()
                Text("Timer")
            }

            Spacer()

            TimelineView(.periodic(from: store.session.startTime, by: 1)) { context in
                Text(verbatim: store.session.displayTime(now: context.date))
                    .onChange(of: store.session.deadline < context.date) { _, isDue in
                        guard !store.session.isDone else { return }
                        if isDue, !store.showsAddTime {
                            store.showsAddTime = true
                        }
                        if !isDue, store.showsAddTime {
                            store.showsAddTime = false
                        }
                    }
            }

            Spacer()
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .overlay {
                    Button {
                        store.session.stop()
                    } label: {
                        Image(systemName: "square.fill")
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 60, height: 60)
        }
        .padding(30)
        .foregroundStyle(store.session.kind.color)
        .background(Color.black, ignoresSafeAreaEdges: .all)
    }
}

struct SessionInfoView: View {
    @Bindable
    var store: StoreOf<SessionFeature>

    var body: some View {
        VStack {
            HStack {
                Button {
                    guard store.session.isDone else {
                        store.showsTimer = true
                        return
                    }

                    store.send(.dismiss)
                } label: {
                    Image(systemName: store.session.isDone ? "arrow.down" : "arrow.backward")
                        .foregroundStyle(.black)
                }
                Spacer()
                Text("Info")
            }

            Spacer()


            HStack {
                Button {
                    store.session.kind = .good
                } label: {
                    Text("Good")
                        .foregroundStyle(.black)
                        .opacity(store.session.kind == .good ? 1 : 0.3)
                }

                Button {
                    store.session.kind = .neutral
                } label: {
                    Text("Neutral")
                        .foregroundStyle(.black)
                        .opacity(store.session.kind == .neutral ? 1 : 0.3)
                }

                Button {
                    store.session.kind = .bad
                } label: {
                    Text("Bad")
                        .foregroundStyle(.black)
                        .opacity(store.session.kind == .bad ? 1 : 0.3)
                }
            }

            Spacer()
        }
        .overlay(alignment: .bottomTrailing) {
            if !store.session.isDone {
                Circle()
                    .overlay {
                        Button {
                            store.session.stop()
                        } label: {
                            Image(systemName: "square.fill")
                                .foregroundStyle(store.session.kind.color)
                        }
                    }
                    .frame(width: 60, height: 60)
            }
        }
        .padding(30)
        .foregroundStyle(Color.black)
        .background(store.session.kind.color, ignoresSafeAreaEdges: .all)
        .onChange(of: store.showsTimer) { _, newValue in
            print("Shows timer?", newValue)

        }
    }
}

struct SessionAddTimeView: View {
    @Bindable
    var store: StoreOf<SessionFeature>

    var body: some View {
        Button {
            store.session.addTime(15)
        } label: {
            Text("Add Time")
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(store.session.kind.color, ignoresSafeAreaEdges: .all)
    }
}

struct SessionPages: View {
    @Bindable
    var store: StoreOf<SessionFeature>

    var body: some View {
        if !store.session.isDone {
            Page(id: "Timer") {
                SessionTimerView(store: store)
            }
            .pageFlow(\.pageBackground, .black)
        }

        Page(id: "Info") {
            SessionInfoView(store: store)
        }
        .tag(store)
        .pageFlow(\.pageBackground, store.session.kind.color)

        if store.showsAddTime {
            Page(id: "AddTime") {
                SessionAddTimeView(store: store)
            }
        }
    }
}

private enum PageBackgroundKey: PageFlowValueKey {
    static var defaultValue: Color { .clear }
}

extension PageFlowValues {
    var pageBackground: Color {
        get { self[PageBackgroundKey.self] }
        set { self[PageBackgroundKey.self] = newValue }
    }
}
