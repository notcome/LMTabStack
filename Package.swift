// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LMTabStack",
    platforms: [
        .iOS("18.0"),
        .macCatalyst("18.0"),
        .macOS("15.0"),
        .watchOS("11.0"),
    ],
    products: [
        .library(
            name: "LMTabStack",
            targets: ["LMTabStack"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.10.0"),
    ],
    targets: [
        .target(
            name: "LMTabStack",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "LMTabStackTests",
            dependencies: [
                "LMTabStack",
            ]
        )
    ]
)
