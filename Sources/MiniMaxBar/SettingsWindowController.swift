import AppKit
import SwiftUI

/// 设置窗口(由右键菜单"设置…"唤出)
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if let w = window {
            // 已存在,前置
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.titlebarAppearsTransparent = true
        w.minSize = NSSize(width: 760, height: 520)
        w.title = "MiniMax Usage"  // 侧栏 header 已有品牌名,标题栏不再带"设置"防重复
        w.contentViewController = NSHostingController(
            rootView: SettingsView(apiKeyInput: KeychainStore.load() ?? "")
        )
        w.isReleasedWhenClosed = false
        w.center()
        w.delegate = self
        self.window = w

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // 让窗口引用释放,下次 show() 重建(避免 SwiftUI 状态卡住)
        window = nil
    }
}
