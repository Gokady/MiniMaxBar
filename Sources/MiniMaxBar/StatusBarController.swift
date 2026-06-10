import AppKit
import SwiftUI
import Combine

/// 状态栏控制器:左键弹 popover,右键弹 NSMenu
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let contextMenu: NSMenu
    private let store = UsageStore.shared
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        contextMenu = NSMenu()
        super.init()
        configureStatusItem()
        configurePopover()
        configureContextMenu()
        observeStore()
        observePopoverCommands()
    }

    /// 监听 SwiftUI 视图发来的关闭 popover 请求(Cmd+W / Esc)
    private func observePopoverCommands() {
        NotificationCenter.default.addObserver(
            forName: .closePopover, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.popover.performClose(nil)
            }
        }
    }

    // MARK: - 配置

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        applyIconToButton(button)
        button.imagePosition = .imageLeft
        button.title = store.statusBarText

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusItem.length = 90
    }

    /// 根据 store.statusBarIcon 设置按钮图标
    private func applyIconToButton(_ button: NSStatusBarButton) {
        let choice = store.statusBarIcon
        if let img = loadIcon(for: choice) {
            // 先置空再赋值,避免 NSStatusBarButton 缓存旧 image
            // —— 修 macOS 26 上"切换单色/彩色图标错位"bug
            button.image = nil
            img.isTemplate = choice.isTemplate
            button.image = img
            button.imageScaling = .scaleProportionallyDown
            button.needsDisplay = true
        } else {
            button.image = NSImage(systemSymbolName: "chart.bar.doc.horizontal",
                                    accessibilityDescription: "MiniMax Usage")
        }
    }

    /// 加载图标(品牌 PNG 或 SF Symbol)
    private func loadIcon(for choice: UsageStore.StatusBarIcon) -> NSImage? {
        // 1. 优先 SF Symbol
        if let name = choice.sfSymbolName {
            let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg)
        }
        // 2. 品牌 PNG(从 bundle 加载)
        let bundle = Bundle.main
        let prefix = choice.bundlePrefix ?? ""
        for suffix in ["@3x", "@2x", ""] {
            let name = "\(prefix)icon_22\(suffix)"
            if let url = bundle.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }

    /// 订阅 store 的关键状态,变化时刷新状态栏文字
    /// 关键:用 DispatchQueue.main.async 把 AppKit 按钮更新推迟到下一个 runloop tick
    /// —— 修 Picker 切换后菜单栏"慢一拍"bug(直接 sink 会被 SwiftUI 正在处理的
    ///    objectWillChange 吞掉,导致要等下一次状态变化才生效)
    private func observeStore() {
        store.$statusBarFormat
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatusBarText() }
            }
            .store(in: &cancellables)

        store.$usage
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatusBarText() }
            }
            .store(in: &cancellables)

        store.$lastUpdated
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatusBarText() }
            }
            .store(in: &cancellables)

        store.$statusBarIcon
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, let btn = self.statusItem.button else { return }
                    self.applyIconToButton(btn)
                }
            }
            .store(in: &cancellables)
    }

    private func refreshStatusBarText() {
        guard let button = statusItem.button else { return }
        button.title = store.statusBarText
        updateStatusItemLength()
    }

    /// 动态调整 status item 宽度,根据图标 + 文字内容计算
    private func updateStatusItemLength() {
        guard let button = statusItem.button else { return }
        let iconWidth: CGFloat = 22
        let padH: CGFloat = 8       // 系统内边距
        let gap: CGFloat = 4        // 图标和文字间距

        let title = button.title
        if title.isEmpty {
            statusItem.length = 24
            return
        }
        let font = button.font ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        // 文字宽 + 图标宽 + 间隙 + 系统 padding,再补 2pt 安全余量
        let total = iconWidth + gap + textSize.width + padH + 2
        statusItem.length = max(28, total)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 250, height: 280)
        popover.animates = true
        let host = NSHostingController(
            rootView: PopoverContentView(store: UsageStore.shared)
        )
        host.sizingOptions = [.preferredContentSize]  // 让 SwiftUI 决定高度
        popover.contentViewController = host
    }

    private func configureContextMenu() {
        addMenuItem("刷新",        key: "r", action: #selector(menuRefresh))
        addSeparator()
        addMenuItem("设置…",       key: ",", action: #selector(menuOpenSettings))
        addMenuItem("网页控制台…", key: "",  action: #selector(menuOpenWeb))
        addSeparator()
        addMenuItem("退出",        key: "q", action: #selector(menuQuit))
    }

    private func addMenuItem(_ title: String, key: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = key.isEmpty ? [] : .command
        contextMenu.addItem(item)
    }

    private func addSeparator() { contextMenu.addItem(.separator()) }

    // MARK: - 点击处理

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            showContextMenu(on: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func showContextMenu(on button: NSStatusBarButton) {
        // 标准套路:临时挂 menu → 触发 click → 摘掉 menu
        // (挂上时左键会变成弹菜单,摘掉后左键恢复弹 popover)
        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 让 popover 拿到焦点
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - 菜单 action

    @objc private func menuRefresh() {
        Task { @MainActor in await UsageStore.shared.refresh() }
    }

    @objc private func menuOpenSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func menuOpenWeb() {
        if let url = URL(string: "https://platform.minimaxi.com/user-center/payment/token-plan") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
