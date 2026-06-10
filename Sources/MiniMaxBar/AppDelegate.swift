import AppKit
import SwiftUI
import Sparkle

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    var statusController: StatusBarController!
    var settingsController: SettingsWindowController!

    /// Sparkle 自动更新控制器(整个 App 生命周期只初始化一次)
    private var sparkleController: SPUStandardUpdaterController!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)

        // 初始化 Sparkle 自动更新
        sparkleController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: UpdateManager.shared,
            userDriverDelegate: nil
        )
        UpdateManager.shared.setupWithController(sparkleController)

        statusController = StatusBarController.shared
        settingsController = SettingsWindowController.shared
        Task { @MainActor in
            UsageStore.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            UsageStore.shared.stop()
        }
    }
}
