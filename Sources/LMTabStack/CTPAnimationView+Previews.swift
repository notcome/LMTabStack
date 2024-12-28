import ComposableArchitecture
import SwiftUI

private enum OffsetDirection: CaseIterable, Identifiable {
    case none
    case east
    case west
    case north
    case south

    var id: Self { self }

    var label: String {
        switch self {
        case .none: "No Change"
        case .east: "East"
        case .west: "West"
        case .north: "North"
        case .south: "South"
        }
    }

    var offset: CGSize {
        switch self {
        case .none: .zero
        case .east: CGSize(width: 50, height: 0)
        case .west: CGSize(width: -50, height: 0)
        case .north: CGSize(width: 0, height: -50)
        case .south: CGSize(width: 0, height: 50)
        }
    }
}

@Reducer
private struct BasicFeature {
    @ObservableState
    struct State: Equatable {
        var opacity: Double = 1.0
        var isScaled: Bool = false
        var offsetDirection: OffsetDirection = .none

        var ctp: CommonTransitionProperties {
            CommonTransitionProperties(
                opacity: opacity,
                offsetX: offsetDirection.offset.width,
                offsetY: offsetDirection.offset.height,
                scaleX: isScaled ? 0.8 : 1,
                scaleY: isScaled ? 0.8 : 1
            )
        }

        var animationInProgress: Bool = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)

        case startAnimation
        case moveToStart
        case moveToEnd
        case endAnimation
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(reduceSelf(state:action:))
    }

    func reduceSelf(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            break

        case .startAnimation:
            guard !state.animationInProgress else { break }
            state.animationInProgress = true
            return .run { send in
                do {
                    await send(.moveToStart)
                    try await Task.sleep(for: .milliseconds(250))

                    var transaction = Transaction()
                    transaction.transitionAnimation = .spring
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
            state.opacity = 0.5
            state.isScaled = true
            state.offsetDirection = .west

        case .moveToEnd:
            guard state.animationInProgress else { break }
            state.opacity = 1
            state.isScaled = false
            state.offsetDirection = .east

        case .endAnimation:
            state = .init()
        }

        return .none
    }
}

@MainActor
private func createBasicFeature() -> StoreOf<BasicFeature> {
    Store(initialState: .init()) {
       BasicFeature()
   }
}

private struct BasicControls: View {
    @Bindable
    var store: StoreOf<BasicFeature>

    var body: some View {
        HStack {
            Text("Opacity")
            Slider(value: $store.opacity, in: 0...1)
        }

        Toggle("Scaled", isOn: $store.isScaled)

        Picker("Offset", selection: $store.offsetDirection) {
            ForEach(OffsetDirection.allCases) { direction in
                Text(direction.label)
                    .tag(direction)
            }
        }

        Button("Trigger animation") {
            store.send(.startAnimation)
        }.disabled(store.animationInProgress)
    }
}

#Preview("Basic View") {
    @Previewable @State var store = createBasicFeature()

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                BasicControls(store: store)
            }

            Section {
                CTPAnimationViewRepresentable(
                    props: store.ctp,
                    content: RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                        .frame(width: 100, height: 100)
                )
                .background(Color.black.opacity(0.1))
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } header: {
                Text("Preview")
            } footer: {
                Text("Background of the view is shown in gray.")
            }
        }
    }
}

#Preview("Basic View Controller") {
    @Previewable @State var store = createBasicFeature()

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                BasicControls(store: store)
            }

            Section {
                CTPAnimationViewControllerRepresentable(
                    props: store.ctp,
                    content: RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                        .frame(width: 100, height: 100)
                )
                .background(Color.black.opacity(0.1))
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } header: {
                Text("Preview")
            } footer: {
                Text("Background of the view controller is shown in gray.")
            }
        }
    }
}

@Reducer
private struct VelocityTrackingFeature {
    @ObservableState
    struct State: Equatable {
        var offsetX: Double?
        var ctp: CommonTransitionProperties? {
            guard let offsetX else { return nil }
            return .init(offsetX: offsetX)
        }
        var animationInProgress: Bool = false
    }

    enum Action {
        case startAnimation(Bool)
        case updateOffsetX(Double)
        case endAnimation
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startAnimation(let tracksVelocity):
            guard !state.animationInProgress else { break }
            state.animationInProgress = true

            return .run { send in
                do {
                    for i in 0...15 {
                        var transaction = Transaction()
                        transaction.tracksVelocity = tracksVelocity
                        await send(.updateOffsetX(Double(i * 10)), transaction: transaction)
                        try await Task.sleep(for: .milliseconds(8))
                    }

                    var transaction = Transaction()
                    transaction.transitionAnimation = .spring
                    let t = transaction.transitionAnimation!.animation.duration
                    await send(.updateOffsetX(0), transaction: transaction)
                    try await Task.sleep(for: .milliseconds(round((t + 0.1) * 1000)))

                    await send(.endAnimation)
                } catch {
                    print("Unexpected error", error)
                    await send(.endAnimation)
                }
            }

        case .updateOffsetX(let x):
            guard state.animationInProgress else { break }
            state.offsetX = x

        case .endAnimation:
            state = .init()
        }
        return .none
    }
}

#Preview("Velocity Tracking") {
    @Previewable @State var store = Store(initialState: .init()) {
        VelocityTrackingFeature()
    }

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                Button("With velocity tracking") {
                    store.send(.startAnimation(true))
                }.disabled(store.animationInProgress)

                Button("Without velocity tracking") {
                    store.send(.startAnimation(false))
                }.disabled(store.animationInProgress)
            }

            Section {
                CTPAnimationViewControllerRepresentable(
                    props: store.ctp,
                    content: RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                        .frame(width: 100, height: 100)
                )
                .overlay {
                    Rectangle()
                        .frame(width: 1)
                        .offset(x: 200)
                }
                .offset(x: -75)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } header: {
                Text("Preview")
            } footer: {
                Text("Without velocity tracking, the blue square's right edge will align precisely with the black line before returning. When velocity tracking is enabled, momentum will carry it slightly past this alignment point before it springs back to its starting position.")
            }
        }
    }
}
