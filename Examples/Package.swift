// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .iOS("18.0"),
        .macCatalyst("18.0"),
        .macOS("15.0"),
        .watchOS("11.0"),
    ],
    products: [
        .library(
            name: "MusicPlayer",
            targets: ["MusicPlayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.10.0"),
        .package(path: "../"),
    ],
    targets: [
        .target(
            name: "MusicPlayer",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "LMTabStack", package: "LMTabStack"),
            ]
        ),
    ]
)
