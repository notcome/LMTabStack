import LMTabStack
import SwiftUI

enum CalendarPageID: Hashable {
    case root
}

struct CalendarView: View {
    var body: some View {
        Text("Calendar")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

struct CalendarStack: View {
    var body: some View {
        TabStack(AppTab.calendar) {
            Page(id: CalendarPageID.root) {
                CalendarView()
            }
        }
    }
}
