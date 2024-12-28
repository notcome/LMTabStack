import ComposableArchitecture
import SwiftUI

@Reducer
struct TestFeature {
    @ObservableState
    struct State {
        var values: TransitionValues = .init()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}

private struct Wrapper {
    var store: StoreOf<TestFeature>
}

extension Wrapper: ViewTransitionModel {
    var transitionInProgress: Bool {
        true
    }

    func access<T>(_ keyPath: KeyPath<TransitionValues, T>) -> T {
        store.state.values[keyPath: keyPath]
    }
}

struct Editor: View {
    @Bindable
    var store: StoreOf<TestFeature>

    var body: some View {
        HStack {
            Button("Offset") {
                withAnimation {
                    if store.values.offsetY == nil {
                        store.values.offsetY = 100
                    } else {
                        store.values.offsetY = nil
                    }
                }
            }
        }
    }
}

struct TestView: View {
    @State
    var hello = Store(initialState: TestFeature.State()) {
        TestFeature()
    }

    @State
    var frame: CGRect? = nil

    var body: some View {
        VStack {
            Text("Hello, world!")
                .padding()
                .background(.blue, ignoresSafeAreaEdges: [])
                .modifier(MorphableCTPModifier())
                .background {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .global)
                        Color.clear
                            .onChange(of: frame, initial: true) {
                                self.frame = frame
                            }
                    }
                }
                .environment(\.viewTransitionModel, Wrapper(store: hello))

            Spacer()

            if let frame {
                Text(CGRectIntegral(frame).debugDescription)
            }

            Spacer()

            Editor(store: hello)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.yellow)
    }
}

#Preview {
    TestView()
}
