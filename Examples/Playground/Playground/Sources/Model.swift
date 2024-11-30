import SwiftUI

@Observable
final class AppModel {
    let home = HomeModel()
    var selectedTab: AppTab = .home

    var showsTabBar: Bool {
        switch selectedTab {
        case .calendar, .progress:
            true
        case .home:
            home.childPage == nil
        }
    }
}
