import Foundation

/// 应用元信息(版本号、GitHub 仓库等)
/// 版本号单一来源 = Resources/Info.plist 的 CFBundleShortVersionString / CFBundleVersion
/// CI(在 release.yml)写入 Info.plist,运行时从这里读
enum AppInfo {
    /// 用户可见的版本号(如 "0.4.0"),运行时从 Info.plist 读
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// 构建号,运行时从 Info.plist 读
    static var build: Int {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return Int(raw ?? "1") ?? 1
    }

    /// GitHub 仓库坐标
    static let githubOwner: String = "Gokady"
    static let githubRepo: String = "MiniMaxBar"

    /// GitHub Releases 页面 URL(用户手动去下载新版用)
    static let releasesPageURL: URL = URL(string:
        "https://github.com/\(githubOwner)/\(githubRepo)/releases"
    )!

    /// GitHub Releases API:获取最新 release 的元信息
    /// (无 appcast.xml,不签 Sparkle 私钥 —— Phase 3 之前用这个 MVP)
    static let latestReleaseAPIURL: URL = URL(string:
        "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
    )!

    /// 用户可见的"当前版本"显示文案
    static var fullVersionString: String { "\(version) (\(build))" }
}
