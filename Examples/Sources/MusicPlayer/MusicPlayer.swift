import ComposableArchitecture
import LMTabStack
import SwiftUI


struct HostingView<Content: View>: UIViewControllerRepresentable {
    @ViewBuilder
    var content: Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        .init(rootView: content)
    }

    func updateUIViewController(_ vc: UIHostingController<Content>, context: Context) {
//        withTransaction(context.transaction) {
        vc.rootView = content
//        }
    }
}

struct TestView: View {
    @State
    var scaled: Bool = false

    var body: some View {
        VStack {
            Button("Toggle") {
                withAnimation(.spring) {
                    scaled.toggle()
                }
            }

            HostingView {
                Circle()
                    .foregroundStyle(.yellow)
                    .frame(width: 160, height: 160)
                    .scaleEffect(scaled ? 0.5 : 1)
            }
            .frame(width: 200, height: 200)
        }
    }
}

#Preview {
    TestView()
}
/*

 TransientView(value: self)

struct StupidTransition {
    var transitions: some View {
        TransientView {
            // view content goes here
        } effects: { proxy in

        }

    }
}

MorphingView(source: xxx, target: xxx, properties) {
    Your views goes here
}

*/
