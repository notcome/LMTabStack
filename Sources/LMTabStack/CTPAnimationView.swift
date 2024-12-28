import SwiftUI

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
typealias PlatformView = NSView

class PlatformLayerBackingView: NSView {
    override var isFlipped: Bool { true }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate var platformLayer: CALayer { layer! }
}

typealias PlatformViewController = NSViewController
#endif

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
typealias PlatformView = UIView
typealias PlatformLayerBackingView = UIView

private extension PlatformLayerBackingView {
    var platformLayer: CALayer { layer }
}

typealias PlatformViewController = UIViewController
#endif

// MARK: View

/// A platform view (`UIView` or `NSView`) that manages animations for ``CommonTransitionProperties`` (CTP).
///
/// This view uses a layered hierarchy where an animation view sits between this view and the content view.
/// This structure ensures that both this view (managed by SwiftUI via a view representable) and the content view
/// (typically a SwiftUI hosting view) remain free of transformations, preventing any conflicts with the framework.
final class CTPAnimationView<ContentView: PlatformView>: PlatformView {
    let animationView: PlatformLayerBackingView
    let contentView: ContentView

    init(contentView: ContentView) {
        self.contentView = contentView
        self.animationView = PlatformLayerBackingView()
        
        super.init(frame: .zero)
        
        addSubview(animationView)
        animationView.addSubview(contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
    override func layoutSubviews() {
        super.layoutSubviews()
        animationView.frame = bounds
        contentView.frame = animationView.bounds
    }
    #endif
    
    #if os(macOS) && !targetEnvironment(macCatalyst)
    override func layout() {
        super.layout()
        animationView.frame = bounds
        contentView.frame = animationView.bounds 
    }
    #endif

    fileprivate var keyPathStates: [String: KeyPathState] = [:]
    fileprivate var velocityTrackers: [String: VelocityTracker] = [:]

    func apply(_ props: CommonTransitionProperties?, transitionAnimation: TransitionAnimation?, tracksVelocity: Bool) {
        guard let props else {
            resetAllAnimations()
            return
        }
        let keyPaths: [(String, KeyPath<CommonTransitionProperties, Double?>)] = [
            ("opacity", \.opacity),
            ("transform.scale.x", \.scaleX),
            ("transform.scale.y", \.scaleY), 
            ("transform.translation.x", \.offsetX),
            ("transform.translation.y", \.offsetY)
        ]

        for (keyPath, valueKeyPath) in keyPaths {
            guard let value = props[keyPath: valueKeyPath] else { continue }
            update(keyPath: keyPath, to: value, transitionAnimation: transitionAnimation, tracksVelocity: tracksVelocity)
        }
    }

    func apply(_ props: CommonTransitionProperties?, transaction: Transaction) {
        apply(props, transitionAnimation: transaction.transitionAnimation, tracksVelocity: transaction.tracksVelocity)
    }
}

private extension CTPAnimationView {
    func resetAllAnimations() {
        animationView.platformLayer.removeAllAnimations()
        keyPathStates = [:]
        velocityTrackers = [:]
    }

    func addConstantAnimation(keyPath: String, value: Double, tracksVelocity: Bool) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = value
        animation.toValue = value
        animation.speed = 0
        animation.isRemovedOnCompletion = false
        animationView.platformLayer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .constant(value)

        if tracksVelocity {
            velocityTrackers[keyPath, default: .init()].addSample(value)
        }
    }

    func addAnimation(_ animation: CABasicAnimation, keyPath: String, from oldValue: Double, to newValue: Double) {
        if requiresFasterFrameRate(keyPath: keyPath) {
            animation.preferredFrameRateRange = .init(minimum: 60, maximum: 120, preferred: 120)
        }
        animation.fromValue = oldValue
        animation.toValue = newValue
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animationView.platformLayer.add(animation, forKey: keyPath)
        keyPathStates[keyPath] = .animating(newValue)
    }

    func update(
        keyPath: String,
        to newValue: Double,
        transitionAnimation: TransitionAnimation?,
        tracksVelocity: Bool
    ) {
        guard let state = keyPathStates[keyPath] else {
            assert(transitionAnimation == nil)
            addConstantAnimation(keyPath: keyPath, value: newValue, tracksVelocity: tracksVelocity)
            return
        }

        switch state {
        case let .constant(oldValue):
            guard oldValue != newValue else { return }
            guard let transitionAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue, tracksVelocity: tracksVelocity)
                return
            }
            let animation: CABasicAnimation
            if let absoluteVelocity = velocityTrackers[keyPath]?.absoluteVelocity, absoluteVelocity != 0 {
                let relativeVelocity = absoluteVelocity / (newValue - oldValue)
                animation = transitionAnimation.animation.createCAAnimation(initialVelocity: relativeVelocity)
            } else {
                animation = transitionAnimation.animation.createCAAnimation()
            }
            addAnimation(animation, keyPath: keyPath, from: oldValue, to: newValue)

        case let .animating(targetValue):
            guard let transitionAnimation else {
                addConstantAnimation(keyPath: keyPath, value: newValue, tracksVelocity: tracksVelocity)
                return
            }
            guard targetValue != newValue else { return }

            assertionFailure("Attempting to animate a property with an in-flight animation. This suggests a bug in LMTabStack.")
            let currentValue = animationView.platformLayer.presentation()?.value(forKeyPath: keyPath) as? Double ?? targetValue
            addAnimation(transitionAnimation.createCAAnimation(), keyPath: keyPath, from: currentValue, to: newValue)
        }
    }
}

// MARK: Utilities

private enum KeyPathState {
    case constant(Double)
    case animating(Double)
}

private func requiresFasterFrameRate(keyPath: String) -> Bool {
    switch keyPath {
    case "opacity":
        false
    default:
        true
    }
}

struct VelocityTracker {
    private var samples: [(CFTimeInterval, Double)] = []
    
    mutating func addSample(_ value: Double) {
        let currentTime = CACurrentMediaTime()
        let pair = (currentTime, value)
        
        switch samples.count {
        case 2:
            guard currentTime - samples[1].0 > 1e-4 else { return }
            samples[0] = samples[1]
            samples[1] = pair
        case 1:
            guard currentTime - samples[0].0 > 1e-4 else { return }
            samples.append(pair)
        case 0:
            samples.append(pair)
        default:
            fatalError()
        }
    }

    var absoluteVelocity: Double {
        switch samples.count {
        case 2:
            let (t1, x1) = samples[0]
            let (t2, x2) = samples[1]
            return (x2 - x1) / (t2 - t1)
        default:
            return 0
        }
    }
}

// MARK: View Controller

class CTPAnimationViewController<ContentViewController: PlatformViewController>: PlatformViewController {
    let contentViewController: ContentViewController

    var ctpAnimationView: CTPAnimationView<PlatformView> {
        view as! CTPAnimationView<PlatformView>
    }
    
    init(contentViewController: ContentViewController) {
        self.contentViewController = contentViewController
        super.init(nibName: nil, bundle: nil)
        addChild(contentViewController)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let animationView = CTPAnimationView<PlatformView>(contentView: contentViewController.view)
        self.view = animationView
        contentViewController.didMove(toParent: self)
    }

    func apply(_ props: CommonTransitionProperties?, transitionAnimation: TransitionAnimation?, tracksVelocity: Bool) {
        ctpAnimationView.apply(props, transitionAnimation: transitionAnimation, tracksVelocity: tracksVelocity)
    }

    func apply(_ props: CommonTransitionProperties?, transaction: Transaction) {
        ctpAnimationView.apply(props, transaction: transaction)
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
/// Wraps a SwiftUI view in a CTPAnimationView.
///
/// This view is iOS-only because macOS's `NSHostingView` lacks a `sizeThatFits` method, preventing proper size inheritance.
/// This limitation is less important on macOS since the hybrid backend provides minimal benefits there. While the hybrid
/// backend remains supported on macOS, we use pure SwiftUI rendering for morphables.
@MainActor
struct CTPAnimationViewRepresentable<Content: View>: UIViewRepresentable {
    var props: CommonTransitionProperties?
    var content: Content

    func makeUIView(context: Context) -> CTPAnimationView<_UIHostingView<Content>> {
        let hostingView = _UIHostingView(rootView: content)
        hostingView.backgroundColor = .clear
        return CTPAnimationView(contentView: hostingView)
    }
    
    func updateUIView(_ view: CTPAnimationView<_UIHostingView<Content>>, context: Context) {
        withTransaction(context.transaction) {
            view.contentView.rootView = content
        }
        view.contentView.layoutIfNeeded()
        view.apply(props, transaction: context.transaction)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CTPAnimationView<_UIHostingView<Content>>, context: Context) -> CGSize? {
        let hostingView = uiView.contentView
        var size = hostingView.sizeThatFits(proposal.replacingUnspecifiedDimensions())
        if proposal.width == nil {
            size.width = hostingView.intrinsicContentSize.width
        }
        if proposal.height == nil {
            size.height = hostingView.intrinsicContentSize.height
        }
        // In a VStack, Text might get clamped due to interactions among siblings.
        // While not perfect, this works.
        return .init(width: ceil(size.width), height: ceil(size.height))
    }
}
#endif

@MainActor
struct CTPAnimationViewControllerRepresentable<Content: View> {
    var props: CommonTransitionProperties?
    var content: Content
}

#if os(macOS) && !targetEnvironment(macCatalyst)
extension CTPAnimationViewControllerRepresentable: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> CTPAnimationViewController<NSHostingController<Content>> {
        let hostingController = NSHostingController(rootView: content)
        return CTPAnimationViewController(contentViewController: hostingController)
    }
    
    func updateNSViewController(_ viewController: CTPAnimationViewController<NSHostingController<Content>>, context: Context) {
        withTransaction(context.transaction) {
            viewController.contentViewController.rootView = content
        }
        viewController.contentViewController.view.layoutSubtreeIfNeeded()
        viewController.apply(props, transaction: context.transaction)
    }
}
#endif

#if os(iOS) || targetEnvironment(macCatalyst)
extension CTPAnimationViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CTPAnimationViewController<UIHostingController<Content>> {
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        return CTPAnimationViewController(contentViewController: hostingController)
    }
    
    func updateUIViewController(_ viewController: CTPAnimationViewController<UIHostingController<Content>>, context: Context) {
        withTransaction(context.transaction) {
            viewController.contentViewController.rootView = content
        }
        viewController.contentViewController.view.layoutIfNeeded()
        viewController.apply(props, transaction: context.transaction)
    }
}
#endif
