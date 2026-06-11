import SwiftUI
import AppKit

extension Notification.Name {
    /// popover 里的 SwiftUI 视图通过这个通知请求关闭 popover
    /// (Cmd+W / Esc 走这条路径,因为 NSPopover 的内容不能直接调 popover.performClose)
    static let closePopover = Notification.Name("com.minimaxi.usage.closePopover")
}

// MARK: - 配色(对照官方控制台 token)

enum Theme {
    static let brandGreen  = Color(red: 0.00, green: 0.71, blue: 0.16)  // rgb(0,180,42)
    static let brandYellow = Color(red: 0.95, green: 0.70, blue: 0.10)
    static let brandOrange = Color(red: 0.95, green: 0.50, blue: 0.10)
    static let brandRed    = Color(red: 0.90, green: 0.20, blue: 0.20)
    static let unlimited   = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let pillBlue    = Color(red: 0.20, green: 0.50, blue: 0.95)
    static let trackGray   = Color(red: 0.93, green: 0.94, blue: 0.95)

    /// 颜色计算
    /// - smooth: 3 段线性插值(0% 红 → 30% 橙 → 60% 黄 → 100% 绿)
    /// - stepped: 20/50 红绿灯(0-20% 红,21-50% 黄,51-100% 绿)
    static func color(forPercent p: Int, mode: UsageStore.BarColorMode = .stepped) -> Color {
        let clamped = max(0, min(100, p))
        let t = Double(clamped) / 100.0
        switch mode {
        case .smooth:
            // 3 段线性:0→30%=红→橙,30→60%=橙→黄,60→100%=黄→绿
            if t < 0.30 {
                let local = t / 0.30
                return mix(brandRed, brandOrange, local)
            } else if t < 0.60 {
                let local = (t - 0.30) / 0.30
                return mix(brandOrange, brandYellow, local)
            } else {
                let local = (t - 0.60) / 0.40
                return mix(brandYellow, brandGreen, local)
            }
        case .stepped:
            // 20/50 红绿灯(Cloud 风格):简洁、可识别、跟 5h/周 5段制语义化一致
            if clamped <= 20 { return brandRed }
            else if clamped <= 50 { return brandYellow }
            else { return brandGreen }
        }
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        // 简化:RGB 线性混合
        let aComps = a.rgbComponents
        let bComps = b.rgbComponents
        return Color(
            red: aComps.r * (1 - t) + bComps.r * t,
            green: aComps.g * (1 - t) + bComps.g * t,
            blue: aComps.b * (1 - t) + bComps.b * t
        )
    }
}

/// 无限样式调色板的命名色(单一来源,加新主题只改这里)
extension Color {
    // 紫蓝绿(violet)
    static let paletteVioletA = Color(red: 0.49, green: 0.23, blue: 0.93)  // 紫
    static let paletteVioletB = Color(red: 0.23, green: 0.51, blue: 0.96)  // 蓝
    static let paletteVioletC = Color(red: 0.13, green: 0.77, blue: 0.37)  // 绿

    // 红橙黄(primary)
    static let palettePrimaryA = Color(red: 0.93, green: 0.27, blue: 0.20)  // 红
    static let palettePrimaryB = Color(red: 0.98, green: 0.55, blue: 0.10)  // 橙
    static let palettePrimaryC = Color(red: 0.98, green: 0.78, blue: 0.20)  // 黄

    // 蓝(blue)—— cyan → sky → blue
    static let paletteBlueA = Color(red: 0.13, green: 0.83, blue: 0.93)  // cyan
    static let paletteBlueB = Color(red: 0.22, green: 0.74, blue: 0.97)  // sky
    static let paletteBlueC = Color(red: 0.23, green: 0.51, blue: 0.96)  // blue
    static let paletteBlueLight = Color(red: 0.61, green: 0.92, blue: 1.0)  // 浅蓝高光

    // 共享元素
    static let paletteGreenCore = Color(red: 0.13, green: 0.77, blue: 0.37)  // 绿色径向(violet 的 core,primary 的 highlight+core)

    // 官方 1:1(MiniMax 官方控制台无限进度条配色)
    static let paletteShimmerStart = Color(red: 0.514, green: 0.329, blue: 0.831)  // rgb(131, 84, 212) 紫
    static let paletteShimmerEnd   = Color(red: 0.235, green: 0.514, blue: 0.965)  // rgb(60, 131, 246)  蓝
    static let paletteShimmerTrack = Color(red: 0.945, green: 0.953, blue: 0.965)  // #f1f3f6          灰
}

extension Color {
    /// 从 SwiftUI Color 提取 RGB 分量(0-1 范围)
    var rgbComponents: (r: Double, g: Double, b: Double) {
        let ns = NSColor(self)
        let rgb = ns.usingColorSpace(.deviceRGB) ?? ns
        return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }
}

// MARK: - VIP 风格(无限额度用,左向右流动)

enum WeeklyUnlimitedStyle: String, CaseIterable, Identifiable, Codable {
    case shimmer       // 流光(官方 1:1):静态紫蓝渐变 + 白色 shimmer 扫光
    case quantumHue    // 色相流 - 渐变 + hue 旋转
    case quantumWave   // 双波流 - 双层同向波
    case breath        // 呼吸 - 主题色流光 + 透明度呼吸

    var id: String { rawValue }
    var label: String {
        switch self {
        case .shimmer:     return "流光"
        case .quantumHue:  return "色相流"
        case .quantumWave: return "双波流"
        case .breath:      return "呼吸"
        }
    }
}

enum SubscriptionPeriod: String, CaseIterable, Identifiable, Codable {
    case monthly   = "月度"
    case quarterly = "季度"
    case yearly    = "年度"
    case lifetime  = "终身"
    case custom    = "自定义"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .monthly:   return "月度会员"
        case .quarterly: return "季度会员"
        case .yearly:    return "年度会员"
        case .lifetime:  return "终身会员"
        case .custom:    return "自定义"
        }
    }
}

// MARK: - 连接状态

enum ConnectionState {
    case noKey, loading, error, connected
    var color: Color {
        switch self {
        case .noKey:     return Color(white: 0.65)
        case .loading:   return Theme.brandYellow
        case .error:     return Theme.brandRed
        case .connected: return Theme.brandGreen
        }
    }
    var label: String {
        switch self {
        case .noKey:     return "未配置"
        case .loading:   return "加载中"
        case .error:     return "异常"
        case .connected: return "已连接"
        }
    }
}

extension UsageStore {
    var connectionState: ConnectionState {
        if !apiKeyConfigured { return .noKey }
        if isLoading { return .loading }
        if lastError != nil { return .error }
        return .connected
    }
}

extension UsageStore.PlanTier {
    var subscriptionPillText: String {
        switch self {
        case .plus:  return "TokenPlanPlus极速版-年度会员"
        case .max:   return "TokenPlanMax极速版-年度会员"
        case .ultra: return "TokenPlanUltra极速版-年度会员"
        case .unknown: return "Token Plan"
        }
    }
}

// MARK: - 弹出面板(紧凑、无滚动)

struct PopoverContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)
            Divider().opacity(0.3)
            VStack(alignment: .leading, spacing: 10) {
                subscriptionPill
                if let err = errorText, store.connectionState == .error {
                    errorRow(err)
                }
                modelsList
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            Divider().opacity(0.3)
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
        .frame(width: 250)
        // 隐藏的快捷键捕获层:
        // - Cmd+R 触发刷新(也通过 NotificationCenter 兜底,防止按钮不可见时失灵)
        // - Cmd+W 关闭 popover(通知 StatusBarController)
        .background(
            HStack {
                Button("") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .hidden()
                Button("") {
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
                .hidden()
            }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("MiniMax Token")
                .font(.subheadline.weight(.semibold))
            StatusDot(state: store.connectionState)
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("刷新 (⌘R)")
            .buttonStyle(.borderless)
            .help("刷新")
        }
    }

    private var subscriptionPill: some View {
        SubscriptionPill(store: store)
    }

    @ViewBuilder
    private var modelsList: some View {
        if !store.apiKeyConfigured {
            Text("右键 → 设置… → 配置 API Key")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let u = store.usage, u.isSuccess, !store.visibleModels.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.visibleModels) { model in
                    ModelCompactSection(model: model, store: store)
                }
            }
        } else if let u = store.usage, u.isSuccess, store.visibleModels.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前套餐无可用模型")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("右键 → 设置 → 切换套餐")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if let err = store.lastError {
            Text(err)
                .font(.caption2)
                .foregroundStyle(Theme.brandRed)
        } else {
            HStack {
                ProgressView().controlSize(.small)
                Text("加载中…").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var errorText: String? {
        guard store.apiKeyConfigured else { return nil }
        return store.lastError
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(Theme.brandRed)
            Text(msg)
                .font(.caption2)
                .foregroundStyle(Theme.brandRed)
                .lineLimit(2)
        }
    }

    /// 底部 footer:左 web 跳转按钮,右 更新时间
    private var footer: some View {
        HStack {
            // 左下:跳转到 web 后台(浏览器图标)
            Button {
                if let url = URL(string: "https://platform.minimaxi.com/console/usage") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "safari.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("打开 Web 后台查看详细用量(趋势图 / 热力图)")
            Spacer()
            if let t = store.lastUpdated {
                Text("更新 \(t.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("从未更新")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - 主题色板预览(在 Picker 中显示)

struct ThemeSwatch: View {
    let theme: UsageStore.UnlimitedTheme
    var body: some View {
        let p = Palette.make(theme)
        // 取前 3 个颜色画一条 18pt 的横条,直观预览
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let stops = p.stops.prefix(4).map { Gradient.Stop(color: $0.1, location: $0.0 / 0.5) }
            // 画一条迷你渐变条
            let cgGradient = Gradient(stops: Array(stops))
            let path = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: h/2)
            ctx.fill(path, with: .linearGradient(
                cgGradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: w, y: 0)
            ))
        }
        .frame(width: 22, height: 10)
    }
}

// MARK: - 状态小点

struct StatusDot: View {
    let state: ConnectionState
    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 7, height: 7)
            .overlay(
                Circle().stroke(state.color.opacity(0.3), lineWidth: 1)
                    .frame(width: 11, height: 11)
            )
            .help(state.label)
    }
}

// MARK: - 订阅 Pill

struct SubscriptionPill: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        // 大蓝点不动 + "Token Plan · [tier]极速版-[period]会员"
        // period 来自 store.subscriptionPeriod,custom 时用 customPeriodText
        let periodText: String = {
            switch store.subscriptionPeriod {
            case .custom:   return store.customPeriodText.isEmpty ? "自定义" : store.customPeriodText
            default:        return store.subscriptionPeriod.displayName
            }
        }()
        let tierText = store.planTier.pillTierName
        HStack(spacing: 6) {
            // 大蓝点 - 固定 6pt
            Circle()
                .fill(Theme.pillBlue)
                .frame(width: 6, height: 6)
            Text("Token Plan · \(tierText)\(tierText.isEmpty ? "" : "-")\(periodText)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.pillBlue)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.pillBlue.opacity(0.10)))
        .overlay(Capsule().stroke(Theme.pillBlue.opacity(0.30), lineWidth: 0.5))
    }
}

// MARK: - 单模型紧凑区

struct ModelCompactSection: View {
    let model: ModelUsage
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            LimitCompactRow(label: "5h 限额",
                            percent: model.currentIntervalRemainingPercent,
                            resetDate: model.endDate,
                            isUnlimited: store.isUnlimited(model, isWeekly: false),
                            style: store.weeklyUnlimitedStyle,
                            theme: store.unlimitedTheme,
                            totalCapacity: capacityFromBoost(model.intervalBoostPermille),
                            showResetTime: true,
                            display: store.quotaDisplay,
                            colorMode: store.barColorMode)

            LimitCompactRow(label: "周限额",
                            percent: model.currentWeeklyRemainingPercent,
                            resetDate: model.weeklyEndDate,
                            isUnlimited: store.isUnlimited(model, isWeekly: true),
                            style: store.weeklyUnlimitedStyle,
                            theme: store.unlimitedTheme,
                            totalCapacity: capacityFromBoost(model.weeklyBoostPermille),
                            showResetTime: false,
                            display: store.quotaDisplay,
                            colorMode: store.barColorMode)
        }
    }

    /// 从 boost_permille 算总容量
    /// permille 2000 = 200% 总容量(就是用户在网页后台看到的"总额度 200%")
    private func capacityFromBoost(_ permille: Int?) -> Int? {
        guard let permille else { return nil }
        return permille / 10
    }
}

// MARK: - 紧凑行

struct LimitCompactRow: View {
    let label: String
    let percent: Int
    let resetDate: Date
    let isUnlimited: Bool
    let style: WeeklyUnlimitedStyle
    let theme: UsageStore.UnlimitedTheme
    let totalCapacity: Int?
    let showResetTime: Bool  // 只在 5h 行 true,周行 false
    let display: UsageStore.QuotaDisplay  // 正/反显示
    let colorMode: UsageStore.BarColorMode  // 进度条颜色模式

    /// 倍率:100% → 1(不显示),200% → 2,150% → 1.5
    private var multiplier: Double? {
        guard let cap = totalCapacity else { return nil }
        let m = Double(cap) / 100.0
        return m == 1.0 ? nil : m
    }

    /// 倍率文字:× 2 / × 1.5 / 空
    private var multiplierText: String {
        guard let m = multiplier else { return "" }
        let formatted = m.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", m)
            : String(format: "%.1f", m)
        return "× \(formatted)"
    }

    /// 按显示方向换算的"已用"百分比
    private var usedPercent: Int {
        max(0, min(100, 100 - percent))
    }

    /// 实际显示的数值(正显示 → 剩余,反显示 → 已用)
    private var displayPercent: Int {
        display == .used ? usedPercent : percent
    }

    /// 进度条按哪个方向填充
    private var barPercent: Int {
        display == .used ? usedPercent : percent
    }

    /// 主文字(剩 N% / 已用 N%)
    private var mainText: String {
        if display == .used {
            return "已用 \(usedPercent)%"
        } else {
            return "剩 \(percent)%"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1:标签 | 进度条(占满) | 数值(贴条)
            HStack(alignment: .center, spacing: 6) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .leading)

                if isUnlimited {
                    WeeklyUnlimitedBar(style: style, theme: theme)
                } else {
                    // percent 是 remaining% 决定颜色;fillAmount 按显示模式决定
                    ThickRoundedBar(percent: percent,
                                    fillAmount: Double(barPercent) / 100,
                                    mode: colorMode)
                }

                if isUnlimited {
                    // 无限时:只显示 ∞ + 无限制(无倍率)
                    HStack(spacing: 2) {
                        Text("∞")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.unlimited)
                        Text("无限制")
                            .font(.caption2)
                            .foregroundStyle(Theme.unlimited)
                    }
                } else {
                    HStack(spacing: 3) {
                        Text(mainText)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.color(forPercent: percent))
                        if !multiplierText.isEmpty {
                            Text(multiplierText)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.brandOrange)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Theme.brandOrange.opacity(0.12))
                                )
                        }
                    }
                }
            }
            // Row 2:重置时间 + 总额度(合并到一行,节省空间)
            if !isUnlimited {
                HStack(spacing: 6) {
                    if showResetTime {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2)
                        Text(resetDescription)
                            .font(.caption2)
                    }
                    if let cap = totalCapacity {
                        if showResetTime {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text("总额度 \(cap)%")
                            .font(.caption2)
                    }
                    Spacer()
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var resetDescription: String {
        let interval = resetDate.timeIntervalSinceNow
        if interval <= 0 { return "即将重置" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h >= 24 { return "\(h / 24) 天 \(h % 24)h 后重置" }
        if h > 0 { return "\(h)h \(m)m 后重置" }
        return "\(m)m 后重置"
    }
}

// MARK: - 8pt 全圆角粗条(纯色填充,颜色按 remaining% 算)

struct ThickRoundedBar: View {
    let percent: Int          // 颜色参考(总是 remaining% 决定颜色)
    let fillAmount: Double   // 实际填充比例(0-1,按显示模式决定)
    let mode: UsageStore.BarColorMode
    var height: CGFloat = 8
    @State private var animatedFill: Double = 0

    /// 纯色,颜色按 remaining% 计算(剩余少 = 越红)
    var currentColor: Color { Theme.color(forPercent: percent, mode: mode) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.trackGray)
                // 纯色填充,fill 由 fillAmount 决定
                Capsule()
                    .fill(currentColor)
                    .frame(width: max(4, geo.size.width * animatedFill))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: animatedFill)
        .onAppear { animatedFill = fillAmount }
        .onChange(of: fillAmount) { _, new in animatedFill = new }
    }
}

// MARK: - 无限额度风格切换

struct WeeklyUnlimitedBar: View {
    let style: WeeklyUnlimitedStyle
    let theme: UsageStore.UnlimitedTheme
    var body: some View {
        switch style {
        case .shimmer:     ShimmerBar()
        case .quantumHue:  QuantumHueBar(theme: theme)
        case .quantumWave: QuantumWaveBar(theme: theme)
        case .breath:      BreathBar(theme: theme)
        }
    }
}

/// 主题色板
struct Palette {
    /// 4 个色:左向右过渡,周期头尾同色形成无缝
    /// violet: 紫 → 蓝 → 绿 → 紫
    /// primary: 红 → 橙 → 黄 → 绿
    let stops: [(Double, Color)]
    let base: Color        // 底色
    let highlight: Color   // 高光(量子流双波的高光层)
    let core: Color        // 能量核心的径向色
}

extension Palette {
    /// 3 个核心色 → 7 个 stop 的无缝循环(0, 0.165, 0.33, 0.5, 0.665, 0.83, 1)
    /// 用于流光/量子流/呼吸等需要"左向右无缝流动"的无限样式
    static func loop(_ a: Color, _ b: Color, _ c: Color) -> [(Double, Color)] {
        [
            (0.000, a), (0.165, b), (0.330, c),
            (0.500, a), (0.665, b), (0.830, c),
            (1.000, a)
        ]
    }

    static func make(_ theme: UsageStore.UnlimitedTheme) -> Palette {
        switch theme {
        case .violet:
            return Palette(
                stops: loop(.paletteVioletA, .paletteVioletB, .paletteVioletC),
                base: .paletteVioletA,
                highlight: .white,
                core: .paletteGreenCore  // 复用
            )
        case .primary:
            return Palette(
                stops: loop(.palettePrimaryA, .palettePrimaryB, .palettePrimaryC),
                base: .palettePrimaryA,
                highlight: .paletteGreenCore,  // 复用
                core: .paletteGreenCore         // 复用
            )
        case .blue:
            return Palette(
                stops: loop(.paletteBlueA, .paletteBlueB, .paletteBlueC),
                base: .paletteBlueB,
                highlight: .paletteBlueLight,
                core: .paletteBlueB
            )
        }
    }
}

// MARK: - VIP 风格实现(全部左向右流动、无缝)

// 1. 流光(官方 1:1) - 静态紫蓝渐变 + 白色 shimmer 从左扫到右
// 对照 MiniMax 官方控制台无限进度条 HTML/CSS:
//   .ui-meter-unlimited-fill  →  紫(rgb 131,84,212)→蓝(rgb 60,131,246) 渐变
//   .ui-meter-shimmer         →  transparent → white(0.55) → transparent 扫光,2.4s 线性
struct ShimmerBar: View {
    @State private var phase: CGFloat = -1
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            ZStack(alignment: .leading) {
                // 底层:灰色轨道(对应 #f1f3f6)
                Capsule().fill(Color.paletteShimmerTrack)

                // 中层:静态紫蓝渐变(对应 .ui-meter-unlimited-fill)
                LinearGradient(
                    colors: [.paletteShimmerStart, .paletteShimmerEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // 顶层:白色 shimmer 扫光(对应 .ui-meter-shimmer)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.55), location: 0.5),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: barWidth)
                .offset(x: barWidth * phase)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .onAppear {
            // 从 -100% 扫到 +100%,linear 2.4s 无限循环(对应 CSS keyframes)
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// 2. 量子流-色相 - 渐变静止 + hue 旋转(对照 .vip6)
struct QuantumHueBar: View {
    @State private var phase: CGFloat = 0
    var height: CGFloat = 8
    let theme: UsageStore.UnlimitedTheme

    init(theme: UsageStore.UnlimitedTheme = .violet) { self.theme = theme; self.height = 8 }

    var body: some View {
        let p = Palette.make(theme)
        GeometryReader { geo in
            let barWidth = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(p.base.opacity(0.12))
                // 2 个周期无缝,左移 1 个周期
                LinearGradient(stops: p.stops.map { Gradient.Stop(color: $0.1, location: $0.0) },
                               startPoint: .leading,
                               endPoint: .trailing)
                    .frame(width: barWidth * 2)
                    .offset(x: barWidth * phase)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = -1
            }
        }
    }
}

// 3. 量子流-双波 - 双层同向波,周期同步 5s/2.5s 实现无缝
struct QuantumWaveBar: View {
    @State private var t1: CGFloat = 0
    @State private var t2: CGFloat = 0
    var height: CGFloat = 8
    let theme: UsageStore.UnlimitedTheme

    init(theme: UsageStore.UnlimitedTheme = .violet) { self.theme = theme; self.height = 8 }

    var body: some View {
        let p = Palette.make(theme)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.base.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                p.base.opacity(0.30),
                                p.base.opacity(0.70),
                                p.base.opacity(0.30),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: geo.size.width * (t1 - 0.35))
                    .blur(radius: 0.5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                p.highlight.opacity(0.20),
                                p.highlight.opacity(0.40),
                                p.highlight.opacity(0.20),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: geo.size.width * (t2 - 0.175))
                    .blur(radius: 0.3)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) { t1 = 1.0 }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { t2 = 1.0 }
        }
    }
}

// 4. 呼吸 - 主题色流光 + 整体透明度呼吸
// 左向右无缝流动(2 周期),叠加缓速透明度脉动,保留"呼吸"律动感
// 颜色跟着主题走(violet/primary/blue),跟其他三个无限样式保持一致
struct BreathBar: View {
    @State private var phase: CGFloat = 0
    @State private var breath: Double = 0.6
    var height: CGFloat = 8
    let theme: UsageStore.UnlimitedTheme

    init(theme: UsageStore.UnlimitedTheme = .violet) { self.theme = theme; self.height = 8 }

    var body: some View {
        let p = Palette.make(theme)
        GeometryReader { geo in
            let barWidth = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(p.base.opacity(0.10))
                LinearGradient(stops: p.stops.map { Gradient.Stop(color: $0.1, location: $0.0) },
                               startPoint: .leading,
                               endPoint: .trailing)
                    .frame(width: barWidth * 2)
                    .offset(x: barWidth * phase)
                    .opacity(breath)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .onAppear {
            // 渐变左移 1 个周期 = 视觉左向右流动
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                phase = -1
            }
            // 整体透明度缓速呼吸
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breath = 1.0
            }
        }
    }
}

// (能量核心已移除)


// MARK: - 设置窗口(NavigationSplitView + Form/Section 标准布局)

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable {
    case account   = "账户"
    case panel     = "面板显示"
    case statusBar = "菜单栏"
    case version   = "版本"
    case advanced  = "高级"

    var id: String { rawValue }
    var title: String { rawValue }
    var icon: String {
        switch self {
        case .account:   return "person.crop.circle"
        case .panel:     return "rectangle.split.3x1"
        case .statusBar: return "menubar.arrow.up.rectangle"
        case .version:   return "arrow.triangle.2.circlepath"
        case .advanced:  return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @StateObject private var store = UsageStore.shared
    @State private var apiKeyInput: String
    @State private var selectedGroup: SettingsGroup = .account

    init(apiKeyInput: String) {
        _apiKeyInput = State(initialValue: apiKeyInput)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            Form {
                switch selectedGroup {
                case .account:   AccountForm(apiKeyInput: $apiKeyInput, store: store)
                case .panel:     PanelForm(store: store)
                case .statusBar: StatusBarForm(store: store)
                case .version:   UpdateForm()
                case .advanced:  AdvancedForm(store: store)
                }
            }
            .formStyle(.grouped)
            .environmentObject(UpdateManager.shared)
        }
        // 隐藏系统 toolbar 里的侧栏 toggle 按钮(就是"折叠按钮")
        .toolbar(.hidden, for: .windowToolbar)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 app header —— 标题栏透明后,这块浮在 traffic light 下方
            // 副标题"设置"已删,避免跟窗口标题"MiniMax Usage 设置"重复
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("MiniMax Usage")
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)        // 避开 traffic light
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 分组标题
            Text("分组")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 4)

            // 显式 Button 行 —— 绕开 List(selection:) 在 macOS 26 上的命中区 bug
            VStack(spacing: 2) {
                ForEach(SettingsGroup.allCases) { group in
                    SidebarRow(
                        group: group,
                        isSelected: selectedGroup == group
                    ) {
                        selectedGroup = group
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // 底部状态(对照 ClashMac 的三个绿点行)
            VStack(alignment: .leading, spacing: 4) {
                statusDot("API Key", ok: store.apiKeyConfigured)
                statusDot("自动刷新", ok: store.apiKeyConfigured && !store.isLoading)
                statusDot("套餐", ok: store.planTier != .unknown)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    }

    private func statusDot(_ label: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 侧栏行(显式 Button,可控选中态)

struct SidebarRow: View {
    let group: SettingsGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .frame(width: 18, alignment: .center)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(group.title)
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
                    .fontWeight(isSelected ? .medium : .regular)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 账户

/// 修 SwiftUI SecureField 在 macOS 上不能 Cmd+V 粘贴的 bug
/// —— 用 NSSecureTextField 通过 NSViewRepresentable 包一层
struct SecurePasteField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.isBezeled = true
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        return field
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SecurePasteField
        init(_ parent: SecurePasteField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSecureTextField else { return }
            parent.text = field.stringValue
        }
    }
}

struct AccountForm: View {
    @Binding var apiKeyInput: String
    @ObservedObject var store: UsageStore

    var body: some View {
        Section {
            SecurePasteField(text: $apiKeyInput, placeholder: "订阅 Key (sk-cp)")
                .frame(maxWidth: 520)
            HStack(spacing: 6) {
                StatusDot(state: store.connectionState)
                Text(store.connectionState.label)
                Spacer()
                Button("清空") {
                    apiKeyInput = ""
                    store.clearAPIKey()
                }
                .controlSize(.small)
            }
            HStack {
                Button {
                    store.saveAPIKey(apiKeyInput)
                    Task { await store.refresh() }
                } label: {
                    Label("保存到 Keychain", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty)
                Spacer()
            }
        } header: {
            Text("API Key")
        } footer: {
            Text("Key 仅保存在 macOS Keychain,不联网。其他设置自动保存。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        Section("我的套餐") {
            Picker("套餐", selection: $store.planTier) {
                ForEach(UsageStore.PlanTier.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
            Picker("周期", selection: $store.subscriptionPeriod) {
                ForEach(SubscriptionPeriod.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            if store.subscriptionPeriod == .custom {
                TextField("自定义周期 (如 终身 会员)", text: $store.customPeriodText)
            }
            HStack {
                Text("当前显示").foregroundStyle(.secondary)
                SubscriptionPill(store: store)
                Spacer()
            }
        }
    }
}

// MARK: - 面板显示

struct PanelForm: View {
    @ObservedObject var store: UsageStore

    private var weeklyModeBinding: Binding<Int> {
        Binding(
            get: {
                if store.weeklyDisplayOverride == nil { return 0 }
                return store.weeklyDisplayOverride! ? 1 : 2
            },
            set: { newValue in
                switch newValue {
                case 0:  store.weeklyDisplayOverride = nil
                case 1:  store.weeklyDisplayOverride = true
                default: store.weeklyDisplayOverride = false
                }
            }
        )
    }

    private var weeklyModeHint: String {
        switch store.weeklyDisplayOverride {
        case .some(true):  return "已强制显示为「无限」"
        case .some(false): return "已强制显示为「受限」(绿→红)"
        case .none:       return "自动:连续观察到 5h 消耗而周额度不变后推断无限"
        }
    }

    var body: some View {
        Section {
            Picker("显示额度", selection: $store.quotaDisplay) {
                ForEach(UsageStore.QuotaDisplay.allCases, id: \.self) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.segmented)
            Picker("颜色", selection: $store.barColorMode) {
                ForEach(UsageStore.BarColorMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            Picker("周限额", selection: weeklyModeBinding) {
                Text("自动").tag(0)
                Text("无限").tag(1)
                Text("受限").tag(2)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("进度条")
        } footer: {
            Text(weeklyModeHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }

        Section("模型") {
            if store.models.isEmpty {
                Text("先在 API Key 配好后再来勾选")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(store.models) { model in
                    Toggle(isOn: Binding(
                        get: { !store.isHidden(model.modelName) },
                        set: { newValue in
                            if newValue { store.showModel(model.modelName) }
                            else { store.hideModel(model.modelName) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                            Text("model: \(model.modelName) · \(model.statusText(model.currentWeeklyStatus))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section("无限样式") {
            Picker("动画", selection: $store.weeklyUnlimitedStyle) {
                ForEach(WeeklyUnlimitedStyle.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            Picker("颜色主题", selection: $store.unlimitedTheme) {
                ForEach(UsageStore.UnlimitedTheme.allCases) { t in
                    HStack(spacing: 6) {
                        ThemeSwatch(theme: t)
                        Text(t.displayName)
                    }
                    .tag(t)
                }
            }
            HStack(spacing: 8) {
                Text("预览").foregroundStyle(.secondary)
                WeeklyUnlimitedBar(style: store.weeklyUnlimitedStyle, theme: store.unlimitedTheme)
                    .frame(width: 180)
                Text("∞").font(.caption.weight(.bold)).foregroundStyle(Theme.unlimited)
                Spacer()
            }
        }
    }
}

// MARK: - 菜单栏

struct StatusBarForm: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Section("菜单栏内容") {
            // 不走 ForEach + HStack,改用显式两个 Text + 显式 .tag
            // —— 修 macOS 26 上 NSSegmentedControl 命中区错位的 bug
            // (点 1 不生效,点 2 才显示 1 的值)
            Picker("图标", selection: $store.statusBarIcon) {
                Text("单色图标").tag(UsageStore.StatusBarIcon.whiteSmooth)
                Text("彩色图标").tag(UsageStore.StatusBarIcon.brandColor)
            }
            .pickerStyle(.segmented)
            Picker("图标后文字", selection: $store.statusBarFormat) {
                ForEach(UsageStore.StatusBarFormat.allCases, id: \.self) { f in
                    Text(f.label).tag(f)
                }
            }
            if store.displayMode == .tracked {
                Picker("跟踪模型", selection: $store.trackedModelName) {
                    ForEach(store.models.isEmpty
                            ? [("general", "通用(文本)")]
                            : store.models.map { ($0.modelName, $0.displayName) },
                            id: \.0) { name, display in
                        Text(display).tag(name)
                    }
                }
            }
        }

        Section("自动刷新") {
            Picker("刷新频率", selection: $store.refreshIntervalMinutes) {
                Text("1 分钟").tag(1.0)
                Text("5 分钟").tag(5.0)
                Text("15 分钟").tag(15.0)
                Text("30 分钟").tag(30.0)
                Text("60 分钟").tag(60.0)
            }
        }
    }
}

// MARK: - 高级

struct AdvancedForm: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Section("原始响应") {
            if !store.rawJSON.isEmpty {
                HStack {
                    Spacer()
                    Button("复制") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(store.rawJSON, forType: .string)
                    }
                    .controlSize(.small)
                }
                ScrollView {
                    Text(store.rawJSON)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
                .frame(maxHeight: 320)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("暂无原始响应").foregroundStyle(.secondary)
                    Text("配置 API Key 并完成一次刷新后,响应会出现在这里。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - 版本(Sparkle 自动更新)

struct UpdateForm: View {
    @EnvironmentObject var update: UpdateManager
    /// 1 分钟一次的「心跳」——驱动"上次检查"和"状态"等时间敏感字段重新渲染
    /// 上次检查本身用自定义格式(不显示秒),定时器只更新一次/分钟,不会"按秒刷新"
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            Section {
                // 当前版本
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text(AppInfo.fullVersionString)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                // 自动更新开关 —— UI 直接双向绑定 Sparkle 的 automaticallyChecksForUpdates
                if update.isReady {
                    Toggle("自动检查更新", isOn: Binding(
                        get: { update.automaticallyChecksForUpdates },
                        set: { update.automaticallyChecksForUpdates = $0 }
                    ))
                } else {
                    HStack {
                        Text("自动更新")
                        Spacer()
                        Text("未初始化")
                            .foregroundStyle(.orange)
                    }
                }

                // 状态行
                HStack(spacing: 6) {
                    statusIcon
                    Text(update.state.description)
                        .foregroundStyle(statusForeground)
                    Spacer()
                }

                // 最新版本(有更新时显示)
                if let latest = update.latestVersion {
                    HStack {
                        Text("最新版本")
                        Spacer()
                        Text("v\(latest)")
                            .foregroundStyle(.blue)
                            .monospaced()
                    }
                }

                // 上次检查时间 —— 走自定义格式,不带秒
                if let last = update.lastCheckDate {
                    HStack {
                        Text("上次检查")
                        Spacer()
                        Text(relativeCheckText(reference: last, now: now))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }

                // 按钮
                HStack {
                    Button {
                        update.checkForUpdates()
                    } label: {
                        Label("立即检查", systemImage: "arrow.clockwise")
                    }
                    .disabled(!update.canCheckForUpdates || update.state.isBusy)

                    Spacer()

                    Button {
                        update.openReleasesPage()
                    } label: {
                        Label("手动下载", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("自动更新")
            } footer: {
                Text("由 Sparkle 2 驱动,每天自动检查一次。手动下载为备用方案。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 更新日志
            if let notes = update.releaseNotes, !notes.isEmpty {
                Section("更新内容") {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        // 隐藏的 1 分钟心跳,触发 now 刷新
        .onReceive(tick) { now = $0 }
    }

    /// 状态行的前景色:失败红、可用蓝、最新绿、其余次要
    private var statusForeground: Color {
        switch update.state {
        case .failed:     return .red
        case .available:  return .blue
        case .upToDate:   return .green
        default:          return .secondary
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch update.state {
        case .idle:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        case .checking, .downloading, .installing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available:
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    /// 自定义"X 时间前"格式,精度只到分钟/小时/天,不会显示秒
    private func relativeCheckText(reference: Date, now: Date) -> String {
        let interval = now.timeIntervalSince(reference)
        if interval < 0 { return "刚刚" }
        if interval < 60 { return "刚刚" }
        let m = Int(interval / 60)
        if m < 60 { return "\(m) 分钟前" }
        let h = m / 60
        if h < 24 { return "\(h) 小时前" }
        let d = h / 24
        if d < 7 { return "\(d) 天前" }
        // 超过 1 周:落回绝对日期(避免长期挂着个"7 天前"误导)
        return reference.formatted(date: .abbreviated, time: .omitted)
    }
}
