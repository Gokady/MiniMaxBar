import Foundation

/// 应用元信息(版本号、GitHub 仓库等),单一来源
/// build.sh 会从 git tag / 手动参数注入 version,这里给个合理默认值
enum AppInfo {
    /// 用户可见的版本号(如 "0.4.0")
    static let version: String = "0.3.0"

    /// 构建号(递增整数,App Store 用;Sparkle 不强制)
    static let build: Int = 1

    /// GitHub 仓库坐标(Sparkle 检查 release 用)
    static let githubOwner: String = "Gokady"
    static let githubRepo: String = "MiniMaxBar"

    /// Sparkle appcast feed URL(GitHub Releases latest 即可,Sparkle 2 支持)
    /// 也可以指向自己 host 的 appcast.xml(用 Sparkle 的 generate_appcast 工具生成)
    static let feedURL: URL = URL(string:
        "https://github.com/\(githubOwner)/\(githubRepo)/releases/latest"
    )!

    /// 用户可见的"当前版本"显示文案
    static var fullVersionString: String { "\(version) (\(build))" }
}
