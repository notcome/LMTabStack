import LMTabStack
import SwiftUI

enum HomePageID: Hashable {
    case root
    case child(HomeChildPage)
}

enum HomeChildPage: Hashable, CaseIterable {
    case childA
    case childB

    var color: Color {
        switch self {
        case .childA:
            .yellow
        case .childB:
            .blue
        }
    }

    var title: String {
        switch self {
        case .childA:
            "Home Child A"
        case .childB:
            "Home Child B"
        }
    }
}

@Observable
final class HomeModel {
    var dummy: Bool = false
    var childPage: HomeChildPage?// = .childA
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
                switch action {
                case .close:
                    withTransitionProvider(rootToChildProvider) {
                        handleAction()
                    }
                default:
                    withTransitionProvider(sideBySideProvider) {
                        handleAction()
                    }
                }
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

struct HomeChildView: View {
    var page: HomeChildPage
    @Environment(HomeModel.self)
    private var model

    var body: some View {
        Text(page.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pageBackground(page.color)
            .overlay(alignment: .topLeading) {
                HomeChildButton(action: .close)
                    .padding(36)
            }
            .overlay(alignment: .topTrailing) {
                HomeChildButton(action: page == .childA ? .toB : .toA)
                    .padding(36)
            }
//            .withHomeChildSwitchingGesture(current: page)
    }
}

struct HomeView: View {
    @Environment(HomeModel.self)
    private var model

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                ForEach(HomeChildPage.allCases, id: \.self) { page in
                    RoundedRectangle(cornerRadius: 30)
                        .foregroundStyle(page.color)
                        .overlay {
                            Text(page.title)
                        }
                        .transitionElement(id: page)
                        .frame(height: 120)
                        .frame(maxWidth: 240)
                        .onTapGesture {
                            guard model.childPage != page else { return}
                            withTransitionProvider(rootToChildProvider) {
                                model.childPage = page
                            }
                        }
                }
            }
            .padding(.horizontal, 30)

            Rectangle()
                .overlay {
                    Rectangle()
                        .foregroundStyle(.black)
                        .frame(width: model.dummy ? 100 : 200, height: 50)
                }
                .foregroundStyle(.green)
                .onTapGesture {
                    withAnimation(.default) {
                        model.dummy.toggle()
                    }
                }
                .transitionElement(id: "Test")
                .frame(width: 300, height: 100)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
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
            Page(id: HomePageID.root) {
                HomeView()
            }

            if let childPage = model.childPage {
                Page(id: HomePageID.child(childPage)) {
                    HomeChildView(page: childPage)
                }
            }
        }
        .environment(model)
    }
}
