import Foundation
import SwiftUI
import AppKit

/// GitHub Releases 检查器(MVP 版本,暂不接 Sparkle)
///
/// 设计原则:
/// - 单例(跨窗口共享)
/// - **不**自动检查(用户点"检查更新"才查,避免无谓请求)
/// - 调 GitHub Releases API 拿 latest release 元信息
/// - 对比当前版本号判断是否需要更新
/// - "下载并安装"按钮 → 打开浏览器到 releases 页面
/// - API 兼容 UpdateForm(同名 State 枚举 / 公开方法 / @Published 字段)
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    // MARK: - 状态

    enum State: Equatable {
        case idle                       // 空闲
        case checking                   // 正在检查
        case upToDate                   // 已是最新
        case available(latest: String, releaseNotes: String?)  // 有新版本
        // ↓ downloading / installing 是为兼容 UpdateForm 保留的死状态
        // (Views.swift 的 statusIcon switch 引用了它们,Phase 3 接 Sparkle 时再激活)
        case downloading                // 当前不进
        case installing                 // 当前不进
        case failed(reason: String)     // 失败
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckDate: Date?

    // MARK: - 内部

    private init() {}

    // MARK: - 公开 API

    /// 手动触发一次检查(用户在设置面板点"检查更新"按钮)
    func checkForUpdates() {
        guard !state.isBusy else { return }
        state = .checking

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let parsed = try await Self.fetchLatestRelease()
                let currentNums = Self.numericVersion(AppInfo.version)
                let latestNums = Self.numericVersion(parsed.numericVersion)
                let isNewer = Self.compareVersions(latestNums, currentNums) > 0

                await MainActor.run {
                    self.lastCheckDate = Date()
                    if isNewer {
                        self.state = .available(
                            latest: parsed.numericVersion,
                            releaseNotes: parsed.body
                        )
                    } else {
                        self.state = .upToDate
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastCheckDate = Date()
                    self.state = .failed(reason: Self.friendlyError(error))
                }
            }
        }
    }

    /// 用户点了"下载并安装"按钮 —— 当前阶段没 Sparkle,引导去浏览器
    /// (Phase 3 接 Sparkle 后改成 Sparkle 下载安装)
    func downloadAndInstall() {
        guard case .available = state else { return }
        NSWorkspace.shared.open(AppInfo.releasesPageURL)
    }

    /// 当前是否有新版本
    var canInstallUpdate: Bool {
        if case .available = state { return true }
        return false
    }

    /// 最新版本号(若有)
    var latestVersion: String? {
        if case .available(let latest, _) = state { return latest }
        return nil
    }

    /// 更新日志(若有)
    var releaseNotes: String? {
        if case .available(_, let notes) = state { return notes }
        return nil
    }

    // MARK: - GitHub API

    /// 调 GitHub Releases API 拿 latest release
    private static func fetchLatestRelease() async throws -> ParsedRelease {
        var request = URLRequest(url: AppInfo.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub 建议加 User-Agent,否则 API 可能返回 403
        request.setValue("MiniMaxBar/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        let raw = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return ParsedRelease(
            numericVersion: raw.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")),
            body: raw.body
        )
    }

    /// GitHub API 响应的最小子集
    private struct GitHubRelease: Codable {
        let tagName: String          // "v0.4.0"
        let body: String?            // markdown release notes

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
        }
    }

    /// 解析后只保留我们用得到的字段
    private struct ParsedRelease {
        let numericVersion: String    // "0.4.0"(剥掉 v 前缀)
        let body: String?
    }

    // MARK: - 版本比较

    /// "0.4.0" → [0, 4, 0],空段按 0 算
    private static func numericVersion(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// 数组字典序比较。返回 1 表示 a > b,-1 表示 a < b,0 表示相等
    private static func compareVersions(_ a: [Int], _ b: [Int]) -> Int {
        let n = max(a.count, b.count)
        for i in 0..<n {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av < bv ? -1 : 1 }
        }
        return 0
    }

    // MARK: - 错误处理

    private enum UpdateError: LocalizedError {
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code): return "HTTP \(code)"
            }
        }
    }

    private static func friendlyError(_ error: Error) -> String {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet: return "无网络连接"
            case .timedOut:                return "请求超时"
            case .cannotFindHost:          return "无法连接 GitHub"
            case .cannotConnectToHost:     return "GitHub 拒绝连接"
            default:                       return "网络错误:\(urlErr.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}

// MARK: - 状态文案

extension UpdateManager.State {
    /// 给 UI 用的状态描述
    var description: String {
        switch self {
        case .idle:                 return "未检查"
        case .checking:             return "正在检查…"
        case .upToDate:             return "已是最新"
        case .available(let v, _):  return "v\(v) 可用"
        case .downloading:          return "下载中…"
        case .installing:           return "安装中…"
        case .failed(let r):        return "失败:\(r)"
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }
}
