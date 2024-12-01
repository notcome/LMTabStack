import IdentifiedCollections
import SwiftUI
import LMTabStack

enum AppTab: Hashable, CaseIterable {
    case calendar
    case home
    case progress
}

extension AppTab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .calendar:
            "Calendar"
        case .home:
            "Home"
        case .progress:
            "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar:
            "calendar"
        case .home:
            "house"
        case .progress:
            "chart.bar.fill"
        }
    }

    var label: some View {
        Label(titleKey, systemImage: systemImage)
    }
}

struct AppTabBar: View {
    @Binding
    var selectedTab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .opacity(tab == selectedTab ? 1 : 0.3)
                    .foregroundStyle(.white)
                    .onTapGesture {
                        withAnimation(.snappy) {
                            selectedTab = tab
                        }
                    }

                if tab != AppTab.allCases.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: 360)
        .background { Color.black }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
