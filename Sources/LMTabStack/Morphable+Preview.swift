import ComposableArchitecture
import SwiftUI

@Reducer
private struct BasicFeature {
    @ObservableState
    struct State: Equatable {
        var first = TransitionValues()
        var second = TransitionValues()
        var third = TransitionValues()
        var animationInProgress: Bool = false
    }

    enum Action {
        case startAnimation
        case moveToStart
        case moveToEnd
        case endAnimation
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startAnimation:
            guard !state.animationInProgress else { break }
            state.animationInProgress = true

            return .run { send in
                do {
                    await send(.moveToStart)
//                    try await Task.sleep(for: .milliseconds(10))

                    var transaction = Transaction()
                    transaction.transitionAnimation = .easeIn(duration: 1)
                    transaction.animation = transaction.transitionAnimation!.createSwiftUIAnimation()
                    let t = transaction.transitionAnimation!.animation.duration
                    await send(.moveToEnd, transaction: transaction)
                    try await Task.sleep(for: .milliseconds(round((t + 0.1) * 1000)))
                    await send(.endAnimation)
                } catch {
                    print("Unexpected error", error)
                    await send(.endAnimation)
                }
            }

        case .moveToStart:
            guard state.animationInProgress else { break }
            state.first.blurRadius = 0
            state.first.opacity = 1

            state.second.blurRadius = 0
            state.second.scaleX = 1
            state.second.scaleY = 1

            state.third.blurRadius = 0
            state.third.offsetY = 0

        case .moveToEnd:
            guard state.animationInProgress else { break }

            state.first.blurRadius = 10
            state.first.opacity = 0

            state.second.blurRadius = 10
            state.second.scaleX = 1e-3
            state.second.scaleY = 1e-3

            state.third.blurRadius = 10
            state.third.offsetY = 300

        case .endAnimation:
            state = .init()
        }
        return .none
    }
}

private struct ViewTransitionModelAdapter: ViewTransitionModel {
    var rootStore: StoreOf<BasicFeature>
    var childStore: Store<TransitionValues, Never>

    init(rootStore: StoreOf<BasicFeature>, keyPath: KeyPath<BasicFeature.State, TransitionValues>) {
        self.rootStore = rootStore
        childStore = rootStore.scope(state: keyPath, action: \.never)
    }

    var transitionInProgress: Bool {
        rootStore.animationInProgress
    }

    func access<T>(_ keyPath: KeyPath<TransitionValues, T>) -> T {
        childStore.state[keyPath: keyPath]
    }
}

private struct BasicElementsStack: View {
    var store: StoreOf<BasicFeature>

    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    var body: some View {
        VStack(spacing: 20) {
            Text(renderingMode == .pure ? "Pure" : "Hybrid")

            Text("First")
                .padding()
                .background(Color.pink)
                .modifier(MorphableModifier())
                .environment(\.viewTransitionModel, ViewTransitionModelAdapter(rootStore: store, keyPath: \.first))

            Text("Second")
                .padding()
                .background(Color.blue)
                .modifier(MorphableModifier())
                .environment(\.viewTransitionModel, ViewTransitionModelAdapter(rootStore: store, keyPath: \.second))

            Text("Third")
                .padding()
                .background(Color.yellow)
                .modifier(MorphableModifier())
                .environment(\.viewTransitionModel, ViewTransitionModelAdapter(rootStore: store, keyPath: \.third))
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    @Previewable @State var store = Store(initialState: .init()) {
        BasicFeature()
    }

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                Button("Trigger animation") {
                    store.send(.startAnimation)
                }.disabled(store.animationInProgress)
            }

            Section {
                HStack {
                    BasicElementsStack(store: store)
                        .environment(\.tabStackRenderingMode, .hybrid)
                    BasicElementsStack(store: store)
                        .environment(\.tabStackRenderingMode, .pure)
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("Preview")
            }
        }
    }
}
