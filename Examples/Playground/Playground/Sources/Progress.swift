import LMTabStack
import SwiftUI

enum ProgressPageID: Hashable {
    case root
}

struct ProgressView: View {
    var body: some View {
        Text("Progress")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

struct ProgressStack: View {
    var body: some View {
        TabStack(AppTab.progress) {
            Page(id: ProgressPageID.root) {
                ProgressView()
            }
        }
    }
}
