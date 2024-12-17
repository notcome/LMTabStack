import LMTabStack
import SwiftUI

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit


struct SwitchChildGestureRecognizer: UIGestureRecognizerRepresentable {
    var current: HomeChildPage

    @Environment(HomeModel.self)
    private var model

    @TransitionInteraction<SideBySide>
    private var interaction

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let pan = gestureRecognizer as! UIPanGestureRecognizer
            let v = pan.velocity(in: nil)
            return abs(v.x) > abs(v.y)
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        return Coordinator()
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let target: HomeChildPage = current == .childA ? .childB : .childA
        let offset = pan.translation(in: nil).x

        switch pan.state {
        case .began:
            $interaction.startInteractiveTransition {
                model.childPage = target
            } provideTransition: { pages in
                let childA = pages[id: HomePageID.child(.childA)]!
                let childB = pages[id: HomePageID.child(.childB)]!
                var t = SideBySide(
                    childA: childA,
                    childB: childB,
                    childAToChildB: current == .childA)
                t.gestureOffset = offset
                return t
            }

        case .changed:
            $interaction.updateTransition {
                $0.gestureOffset = offset
            }

        case .ended:
            let offset = pan.translation(in: nil)
            let finalOffset = offset.target(initialVelocity: pan.velocity(in: nil)).x
            let width = interaction!.childA.frame.width
            let shouldComplete = switch current {
            case .childA:
                -finalOffset >= width / 2
            case .childB:
                finalOffset >= width / 2
            }

            $interaction.completeTransition {
                if !shouldComplete {
                    model.childPage = current
                }
            } updateTransition: {
                $0.unitOffset = shouldComplete ? 1 : 0
                $0.isComplete = true
            }
        default:
            return
        }
    }
}

extension View {
    func withHomeChildSwitchingGesture(current: HomeChildPage) -> some View {
        gesture(SwitchChildGestureRecognizer(current: current))
    }
}
#else
extension View {
    func withHomeChildSwitchingGesture(current: HomeChildPage) -> some View {
        self
    }
}
#endif
