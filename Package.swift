// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MiniMaxBar",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "MiniMaxBar", targets: ["MiniMaxBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MiniMaxBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MiniMaxBar"
        )
    ]
)
