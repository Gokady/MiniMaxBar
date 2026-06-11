import Foundation
import SwiftUI
import AppKit
import Sparkle

/// 自动更新管理器(Sparkle 2)
///
/// 使用 SPUStandardUpdaterController 驱动更新流程:
/// - 自动检查:由 Info.plist 的 SUEnableAutomaticChecks + SUScheduledCheckInterval 控制
/// - 手动检查:用户点"检查更新"按钮 → checkForUpdates()
/// - 下载/安装/重启:Sparkle 全自动处理
///
/// 状态通过 SPUUpdaterDelegate 回调同步到 @Published 属性,供 UI 绑定。
@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    // MARK: - 状态

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(latest: String, releaseNotes: String?)
        case downloading
        case installing
        case failed(reason: String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckDate: Date?

    // MARK: - Sparkle

    /// Sparkle 控制器(惰性初始化,需要 AppDelegate 先设置 shared)
    private var controller: SPUStandardUpdaterController?

    /// 是否已初始化
    var isReady: Bool { controller != nil }

    /// Sparkle updater 是否允许检查更新
    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    /// 自动检查是否启用(双向可写,UI 改完会回写到 Sparkle)
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            guard let controller, controller.updater.automaticallyChecksForUpdates != newValue else { return }
            controller.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    /// 检查间隔(秒)
    var updateCheckInterval: TimeInterval {
        get { controller?.updater.updateCheckInterval ?? 86400 }
        set { controller?.updater.updateCheckInterval = newValue }
    }

    private override init() {
        super.init()
    }

    // MARK: - 初始化

    /// 由 AppDelegate 在 applicationDidFinishLaunching 中调用
    func setupWithController(_ controller: SPUStandardUpdaterController) {
        self.controller = controller
        // Sparkle 会按 Info.plist 的 SUScheduledCheckInterval 定时检查
    }

    // MARK: - 公开 API

    /// 手动检查更新(Sparkle 会弹出标准更新对话框)
    func checkForUpdates() {
        guard let controller else {
            state = .failed(reason: "更新器未初始化")
            return
        }
        guard canCheckForUpdates else {
            state = .failed(reason: "当前不允许检查更新")
            return
        }
        state = .checking
        controller.checkForUpdates(nil)
    }

    /// 打开 GitHub Releases 页面(fallback)
    func openReleasesPage() {
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

    // MARK: - 状态更新

    fileprivate func setState(_ newState: State) {
        state = newState
        if newState != .checking {
            lastCheckDate = Date()
        }
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        setState(.available(
            latest: item.displayVersionString,
            releaseNotes: item.itemDescription
        ))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        setState(.upToDate)
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        setState(.downloading)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        setState(.installing)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        // Sparkle 在"没找到更新"时也可能走 didAbortWithError,带同样的 SUNoUpdateError。
        // 跟 didFinishUpdateCycleFor 用同一个判断,避免 .upToDate 被覆盖成 .failed
        // (失败文案就会变成"您使用的就是最新版本!"这种 Sparkle 本地化提示)。
        if isNoUpdateError(error) {
            setState(.upToDate)
            return
        }
        setState(.failed(reason: Self.friendlyError(error)))
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        // 关键:Sparkle 在「没有可用更新」时会回 SUNoUpdateError,SUI 的处理方式是先回调
        // updaterDidNotFindUpdate(_:error:)(已置为 .upToDate),再走这里。如果不识别错误码,
        // .upToDate 会被这条回调覆盖成 .failed,UI 就会出现「失败:您使用的就是最新版本!」。
        if let error, !isNoUpdateError(error) {
            setState(.failed(reason: Self.friendlyError(error)))
            return
        }
        // 走到这里 = 真的是「没找到更新」或「成功」。
        // 如果 updaterDidNotFindUpdate 已经先置过 .upToDate,这里就不动;否则把 .checking 收尾。
        if case .checking = state {
            setState(.upToDate)
        }
    }

    /// 识别 Sparkle 的「没找到更新」信号(不同 API 路径都会回这个错误)
    /// 错误码直接用数字 1001(SUNoUpdateError),避免依赖 Sparkle 头文件导出
    /// SUSparkleErrorDomain 同理("SUSparkleErrorDomain")
    private func isNoUpdateError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "SUSparkleErrorDomain",
           nsError.code == 1001 {
            return true
        }
        return false
    }

    private static func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            switch code {
            case .notConnectedToInternet: return "无网络连接"
            case .timedOut: return "请求超时"
            case .cannotFindHost: return "无法连接更新服务器"
            case .cannotConnectToHost: return "更新服务器拒绝连接"
            default: break
            }
        }
        return nsError.localizedDescription
    }
}

// MARK: - 状态文案

extension UpdateManager.State {
    var description: String {
        switch self {
        case .idle:                 return "未检查"
        case .checking:             return "正在检查…"
        case .upToDate:             return "已是最新版本"
        case .available(let v, _):  return "v\(v) 可用"
        case .downloading:          return "下载中…"
        case .installing:           return "安装中…"
        case .failed(let r):        return r
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }
}
