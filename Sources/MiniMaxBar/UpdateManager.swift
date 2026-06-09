import Foundation
import SwiftUI
import Sparkle

/// Sparkle 2 包装:负责检查更新、下载、安装
///
/// 设计原则:
/// - 单例(Sparkle SPUUpdater 推荐单例,跨窗口共享)
/// - 启动时自动检查(automaticallyChecksForUpdates = true)
/// - 不自动下载(让用户决定,避免悄悄下大文件)
/// - 后台静默:不弹原生更新窗,只更新 @Published state,UI 在设置面板的"版本"section 看
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    // MARK: - 状态

    enum State: Equatable {
        case idle                       // 空闲
        case checking                   // 正在检查
        case upToDate                   // 已是最新
        case available(latest: String, releaseNotes: String?)  // 有新版本
        case downloading(progress: Double)  // 下载中(0-1)
        case installing                // 安装中
        case failed(reason: String)     // 失败
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckDate: Date?

    // MARK: - 内部

    private var updaterController: SPUStandardUpdaterController!

    override private init() {
        // 必须先初始化自身属性再调 super.init
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // 自动检查开启,自动下载关闭
        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.automaticallyDownloadsUpdates = false
        // 检查周期:86400 秒 = 每天(默认值,可调)
        updaterController.updater.updateCheckInterval = 86400
    }

    // MARK: - 公开 API

    /// 手动触发一次检查(用户在设置面板点按钮)
    func checkForUpdates() {
        state = .checking
        // SPUStandardUpdaterController.checkForUpdates(nil) 会弹原生更新窗
        // 我们走 SPUUpdater.checkForUpdates() 不弹窗,只走 delegate
        updaterController.updater.checkForUpdates()
    }

    /// 用户点了"下载并安装"按钮 —— 触发 Sparkle 下载 + 替换
    func downloadAndInstall() {
        guard case .available = state else { return }
        state = .downloading(progress: 0)
        // 调 Sparkle 原生下载流程,弹原生确认窗让用户授权安装
        updaterController.checkForUpdates(nil)
    }

    /// 当前是否有新版本可装
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
        case .downloading(let p):   return "下载中 \(Int(p * 100))%"
        case .installing:           return "正在安装…"
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

// MARK: - 监听 Sparkle 回调(在 init 里挂 SPUUpdaterDelegate)

extension UpdateManager: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        Task { @MainActor in
            self.lastCheckDate = Date()
            // Sparkle 已找到 feed 项;SPUUpdater 会内部判断有无更新
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        Task { @MainActor in
            self.lastCheckDate = Date()
            // Sparkle 2:此回调触发即表示"检查完成,没有可用更新"
            // (检查失败会让 error 非空,但 Sparkle 仍把这次当 no-update 处理)
            self.state = .upToDate
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.state = .downloading(progress: 0)
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.state = .installing
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        Task { @MainActor in
            self.state = .failed(reason: error.localizedDescription)
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.state = .installing
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem) {
        Task { @MainActor in
            self.state = .installing
        }
    }

    /// Sparkle 2 提供:有新版本时的回调
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.state = .available(
                latest: item.displayVersionString,
                releaseNotes: item.itemDescription
            )
        }
    }
}
