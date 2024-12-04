import LMTabStack
import SwiftUI

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit


struct SwitchChildGestureRecognizer: UIGestureRecognizerRepresentable {
    var current: HomeChildPage

    @Environment(HomeModel.self)
    private var model

    @InteractiveTransition<SideBySide>
    private var interactiveTransition

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
            $interactiveTransition.startInteractiveTransition {
                model.childPage = target
            } provideTransition: { pages in
                let childA = pages[id: AnyPageID(HomePageID.child(.childA))]!
                let childB = pages[id: AnyPageID(HomePageID.child(.childB))]!
                return SideBySide(
                    childA: childA,
                    childB: childB,
                    childAToChildB: current == .childA,
                    gestureOffset: offset)
            }

        case .changed:
            $interactiveTransition.updateTransition {
                $0.gestureOffset = offset
            }

        case .ended:
            let offset = pan.translation(in: nil)
            let finalOffset = offset.target(initialVelocity: pan.velocity(in: nil)).x
            let width = interactiveTransition!.childA.frame.width
            let shouldComplete = switch current {
            case .childA:
                -finalOffset >= width / 2
            case .childB:
                finalOffset >= width / 2
            }

            if shouldComplete {
                $interactiveTransition.completeTransition {
                    switch current {
                    case .childA:
                        $0.gestureOffset = -width
                    case .childB:
                        $0.gestureOffset = width
                    }
                }
            } else {
                $interactiveTransition.cancelTransition {
                    model.childPage = current
                } updateTransition: {
                    $0.gestureOffset = 0
                }
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
