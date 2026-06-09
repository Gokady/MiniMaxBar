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
        // Sparkle 已禁用(PR #4 改用 GitHub Releases API),不再需要 SPM 依赖
        // 否则二进制 link 了 @rpath/Sparkle.framework 但 .app bundle 不带 framework → 启动 crash
    ],
    targets: [
        .executableTarget(
            name: "MiniMaxBar",
            path: "Sources/MiniMaxBar"
        )
    ]
)
