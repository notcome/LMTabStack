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
private struct PreviewFeature {
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
private func createPreviewFeature() -> StoreOf<PreviewFeature> {
    Store(initialState: .init()) {
       PreviewFeature()
   }
}

private struct PreviewControls: View {
    @Bindable
    var store: StoreOf<PreviewFeature>

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

        Button("Trigger Animation") {
            store.send(.startAnimation)
        }.disabled(store.animationInProgress)
    }
}

#Preview("View Basics") {
    @Previewable @State var store = createPreviewFeature()

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                PreviewControls(store: store)
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

#Preview("View Controller Basics") {
    @Previewable @State var store = createPreviewFeature()

    VStack(spacing: 100) {
        Form {
            Section("Controls") {
                PreviewControls(store: store)
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
