import LMTabStack
import SwiftUI

enum HomePageID: Hashable {
    case root
    case child(HomeChildPage)
}

enum HomeChildPage: Hashable {
    case childA
    case childB
}

@Observable
final class HomeModel {
    var childPage: HomeChildPage?
}

struct HomeChildButton: View {
    enum Action {
        case close
        case toB
        case toA

        var icon: String {
            switch self {
            case .close:
                "xmark"
            case .toB:
                "arrow.forward"
            case .toA:
                "arrow.backward"
            }
        }
    }

    var action: Action

    @Environment(HomeModel.self)
    private var model

    var body: some View {
        Circle()
            .foregroundStyle(.black)
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: action.icon)
                    .foregroundStyle(.white)
            }
            .onTapGesture {
//                withAnimation {
                    handleAction()
//                }
            }
    }

    func handleAction() {
        switch action {
        case .close:
            model.childPage = nil
        case .toB:
            model.childPage = .childB
        case .toA:
            model.childPage = .childA
        }
    }
}

struct HomeChildA: View {
    var body: some View {
        Page(id: HomePageID.child(.childA)) {
            Text("Home Child A")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground(Color.yellow)
                .overlay(alignment: .topLeading) {
                    HomeChildButton(action: .close)
                        .padding(36)
                }
                .overlay(alignment: .topTrailing) {
                    HomeChildButton(action: .toB)
                        .padding(36)
                }
        }
    }
}

struct HomeChildB: View {
    var body: some View {
        Page(id: HomePageID.child(.childB)) {
            Text("Home Child B")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pageBackground(Color.blue)
                .overlay(alignment: .topLeading) {
                    HomeChildButton(action: .close)
                        .padding(36)
                }
                .overlay(alignment: .topTrailing) {
                    HomeChildButton(action: .toA)
                        .padding(36)
                }
        }
    }
}

struct HomeView: View {
    @Environment(HomeModel.self)
    private var model

    var body: some View {
        Page(id: HomePageID.root) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 30)
                    .foregroundStyle(.yellow)
                    .overlay {
                        Text("Home Child A")
                    }
                    .transitionElement(id: HomeChildPage.childA)
                    .frame(height: 120)
                    .frame(maxWidth: 240)
                    .onTapGesture {
                        if model.childPage != .childA {
//                            withAnimation {
                                model.childPage = .childA
//                            }
                        }
                    }

                RoundedRectangle(cornerRadius: 30)
                    .foregroundStyle(.blue)
                    .overlay {
                        Text("Home Child B")
                    }
                    .transitionElement(id: HomeChildPage.childB)
                    .frame(height: 120)
                    .frame(maxWidth: 240)
                    .onTapGesture {
                        if model.childPage != .childB {
//                            withAnimation {
                                model.childPage = .childB
//                            }
                        }
                    }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
        }
    }
}

struct HomeStack: View {
    @Environment(AppModel.self)
    private var appModel

    var model: HomeModel {
        appModel.home
    }

    var body: some View {
        TabStack(AppTab.home) {
            HomeView()

            Group {
                if let childPage = model.childPage {
                    switch childPage {
                    case .childA:
                        HomeChildA()
                    case .childB:
                        HomeChildB()
                    }
                }
            }
        }
        .environment(model)
    }
}
