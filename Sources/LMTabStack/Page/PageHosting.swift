import ComposableArchitecture
import SwiftUI

@MainActor
protocol TabStackCoordinator {
    func pageCoordinator(for pageID: AnyPageID) -> (any PageCoordinator)?
}

@MainActor
protocol PageCoordinator {
    var id: AnyPageID { get }

    var placement: PagePlacement { get }
    var hidden: Bool { get }

    var committedTransitionToken: Int? { get }

    func update(mountedLayout: PageMountedLayout)

    var pageTransitionModel: any ViewTransitionModel { get }
    func morphableTransitionModel(for morphableID: AnyMorphableID) -> (any ViewTransitionModel)?
}

extension EnvironmentValues {
    @Entry
    var tabStackCoordinator: (any TabStackCoordinator)? = nil
    @Entry
    var pageCoordinator: (any PageCoordinator)? = nil
}
