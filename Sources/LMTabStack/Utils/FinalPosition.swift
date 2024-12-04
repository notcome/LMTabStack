import SwiftUI

public extension CGPoint {
    // The target points after decelerating to 0 velocity at a constant rate
    func target(initialVelocity: CGPoint, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGPoint {
        let x = self.x + self.x.target(initialVelocity: initialVelocity.x, decelerationRate: decelerationRate.rawValue)
        let y = self.y + self.y.target(initialVelocity: initialVelocity.y, decelerationRate: decelerationRate.rawValue)
        return CGPoint(x: x, y: y)
    }
}

private extension CGFloat {
    func target(initialVelocity: CGFloat, decelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue) -> CGFloat {
        return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }
}
