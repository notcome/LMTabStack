import ComposableArchitecture
import SwiftUI

private enum Vertex: Hashable, Sendable, CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

@Reducer
private struct BasicFeature {
    @ObservableState
    struct State: Equatable {
        var page = TransitionValues()
        var morphables: [Vertex: TransitionValues] = .init(uniqueKeysWithValues: Vertex.allCases.map { ($0, .init()) })
        var animationInProgress: Bool = false
    }

    enum Action {
        case startAnimation
        case moveToStart
        case moveToTrack1
        case moveToTrack2
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

                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            var tx = Transaction()
                            tx.transitionAnimation = .easeIn(duration: 1)
                            tx.animation = tx.transitionAnimation!.createSwiftUIAnimation()
                            await send(.moveToTrack1, transaction: tx)
                        }
                        group.addTask {
                            var tx = Transaction()
                            tx.transitionAnimation = .easeIn(duration: 2)
                            tx.animation = tx.transitionAnimation!.createSwiftUIAnimation()
                            await send(.moveToTrack2, transaction: tx)
                        }
                    }
                    try await Task.sleep(for: .milliseconds(2100))
                    await send(.endAnimation)
                } catch {
                    print("Unexpected error", error)
                    await send(.endAnimation)
                }
            }

        case .moveToStart:
            guard state.animationInProgress else { break }

            for vertex in Vertex.allCases {
                state.morphables[vertex, default: .init()].offsetX = 0
                state.morphables[vertex, default: .init()].offsetY = 0
            }

            state.page.blurRadius = 0
            state.page.opacity = 1
            state.page.scaleX = 1
            state.page.scaleY = 1

        case .moveToTrack1:
            guard state.animationInProgress else { break }

            state.morphables[.topLeading]!.offsetX = -50
            state.morphables[.topLeading]!.offsetY = -50

            state.morphables[.topTrailing]!.offsetX = 50
            state.morphables[.topTrailing]!.offsetY = -50

            state.morphables[.bottomLeading]!.offsetX = -50
            state.morphables[.bottomLeading]!.offsetY = 50

            state.morphables[.bottomTrailing]!.offsetX = 50
            state.morphables[.bottomTrailing]!.offsetY = 50

        case .moveToTrack2:
            guard state.animationInProgress else { break }

            state.page.blurRadius = 10
            state.page.opacity = 0
            state.page.scaleX = 0.5
            state.page.scaleY = 0.5


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

private struct BasicPage: View {
    @Environment(\.tabStackRenderingMode)
    private var renderingMode

    @State
    private var count = 0

    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.yellow)
                .frame(width: 50, height: 50)
                .morphable(id: Vertex.topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Circle()
                .foregroundStyle(.yellow)
                .frame(width: 50, height: 50)
                .morphable(id: Vertex.topTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Circle()
                .foregroundStyle(.yellow)
                .frame(width: 50, height: 50)
                .morphable(id: Vertex.bottomLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Circle()
                .foregroundStyle(.yellow)
                .frame(width: 50, height: 50)
                .morphable(id: Vertex.bottomTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Text(renderingMode == .hybrid ? "Hybrid" : "Pure")
        }
        .background(Color.blue, ignoresSafeAreaEdges: .all)
    }
}

@MainActor
private struct PageCoordinatorAdapter: PageCoordinator {
    var store: StoreOf<BasicFeature>
    var frame: CGRect

    var id: AnyPageID {
        .init("Basic")
    }

    var placement: PagePlacement {
        var insets = EdgeInsets()
        insets.top = (frame.height - 300) / 2
        insets.bottom = (frame.height - 300) / 2

        return .init(zIndex: 0, frame: frame, safeAreaInsets: insets)
    }

    var hidden: Bool {
        false
    }

    var committedTransitionToken: Int? {
        nil
    }

    func update(mountedLayout: PageMountedLayout) {
    }

    var pageTransitionModel: any ViewTransitionModel {
        ViewTransitionModelAdapter(rootStore: store, keyPath: \.page)
    }

    func morphableTransitionModel(for morphableID: AnyMorphableID) -> (any ViewTransitionModel)? {
        guard let vertex = morphableID.base as? Vertex else { return nil }
        return ViewTransitionModelAdapter(rootStore: store, keyPath: \.morphables[vertex]!)
    }
}

private struct Simulator: View {
    var store: StoreOf<BasicFeature>

    var body: some View {
        GeometryReader { proxy in
            BasicPage()
                .modifier(PageModifier())
                .environment(\.pageCoordinator, PageCoordinatorAdapter(store: store, frame: .init(origin: .zero, size: proxy.size)))
        }
    }
}

#Preview {
    @Previewable @State var hybrid = true
    @Previewable @State var store = Store(initialState: .init()) {
        BasicFeature()
    }

    // A UIHostingController cannot take a view modifier's content as root view inside a Form.
    // Therefore, we use a plain VStack here.
    VStack(spacing: 50) {
        VStack {
            Button(hybrid ? "Use pure" : "Use hybrid") {
                hybrid.toggle()
            }

            Button("Trigger animation") {
                store.send(.startAnimation)
            }

            Divider()

            Text("The four balls should not stick to top/bottom due to safe area. During animation, they will blow out first, but then be pulled back by the page scaling animation. The whole page should *gradually* fade out via both alpha and blur.")
        }.disabled(store.animationInProgress)

        Simulator(store: store)
            .frame(height: 400)
            .environment(\.tabStackRenderingMode, hybrid ? .hybrid : .pure)
    }
    .padding(.horizontal, 20)
}
