import Foundation
import Combine
import AppKit
import SwiftUI
import CryptoKit

@MainActor
final class UsageStore: ObservableObject {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case minPercent    // 状态栏显示所有模型中的最小剩余百分比
        case tracked       // 显示用户指定的某个模型
        case iconOnly      // 只显示图标
        var id: String { rawValue }
        var label: String {
            switch self {
            case .minPercent: return "最紧张模型的剩余 %"
            case .tracked:    return "指定模型的剩余 %"
            case .iconOnly:   return "仅图标"
            }
        }
    }

    enum PlanTier: String, CaseIterable, Identifiable {
        case plus, max, ultra, unknown
        var id: String { rawValue }
        var label: String {
            switch self {
            case .plus: return "Plus"
            case .max: return "Max"
            case .ultra: return "Ultra"
            case .unknown: return "未指定"
            }
        }
        /// pill 显示用的"X极速版"段
        var pillTierName: String {
            switch self {
            case .plus:  return "Plus极速版"
            case .max:   return "Max极速版"
            case .ultra: return "Ultra极速版"
            case .unknown: return ""
            }
        }
    }

    /// 状态栏图标后显示什么(可编辑)
    enum StatusBarFormat: String, CaseIterable, Identifiable, Codable {
        case fiveHourAndWeekly  // " 89%/100%"
        case fiveHourOnly       // " 89%"
        case weeklyOnly         // " 100%"
        case usedPercent5h      // " 11% used" (5h 已用)
        case usedPercentAll     // " 11%/0%" (5h+周已用)
        case iconOnly           // ""

        var id: String { rawValue }
        var label: String {
            switch self {
            case .fiveHourAndWeekly: return "5h/周 剩余 %"
            case .fiveHourOnly:      return "仅 5h 剩余 %"
            case .weeklyOnly:        return "仅周剩余 %"
            case .usedPercent5h:     return "5h 已用 %"
            case .usedPercentAll:    return "5h/周 已用 %"
            case .iconOnly:          return "仅图标(不显示文字)"
            }
        }
    }

    /// 额度显示方向
    enum QuotaDisplay: String, CaseIterable, Identifiable, Codable {
        case remaining   // 正显示:展示剩余量(剩 N%)
        case used        // 反显示:展示已用量(已用 N%)

        var id: String { rawValue }
        var label: String {
            switch self {
            case .remaining: return "剩余额度"
            case .used:      return "已用额度"
            }
        }
    }

    /// 进度条颜色模式
    enum BarColorMode: String, CaseIterable, Identifiable, Codable {
        case stepped   // 阶梯:20/50 红绿灯(0-20% 红,21-50% 黄,51-100% 绿)
        case smooth    // 平滑:0-30% 红→橙,30-60% 橙→黄,60-100% 黄→绿 线性插值

        var id: String { rawValue }
        var label: String {
            switch self {
            case .smooth:  return "渐变"
            case .stepped: return "阶梯"
            }
        }
    }

    /// 状态栏图标预设(只保留两个默认)
    enum StatusBarIcon: String, CaseIterable, Identifiable, Codable {
        case whiteSmooth    // 默认:白平滑波纹(template,自动深浅)
        case brandColor     // 品牌彩色原版

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .whiteSmooth:  return "单色图标"
            case .brandColor:   return "彩色图标"
            }
        }

        var sfSymbolName: String? {
            nil  // 都不使用 SF Symbol
        }

        var bundlePrefix: String? {
            switch self {
            case .whiteSmooth:  return ""
            case .brandColor:   return "color/"
            }
        }

        var isTemplate: Bool {
            switch self {
            case .brandColor:  return false
            case .whiteSmooth: return true
            }
        }
    }

    /// 无限额度条颜色主题
    enum UnlimitedTheme: String, CaseIterable, Identifiable, Codable {
        case violet     // 紫蓝绿
        case primary    // 红橙黄
        case blue       // 蓝

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .violet:   return "紫蓝绿"
            case .primary:  return "红橙黄"
            case .blue:     return "蓝"
            }
        }
    }

    @Published private(set) var rawJSON: String = ""
    @Published private(set) var usage: TokenPlanUsage?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false
    /// 套餐到期日(从订阅 API 读)
    @Published private(set) var subscriptionEndDate: Date?

    @Published var refreshIntervalMinutes: Double {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: Keys.refreshInterval)
            restartTimer()
        }
    }
    @Published var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }
    @Published var planTier: PlanTier {
        didSet { UserDefaults.standard.set(planTier.rawValue, forKey: Keys.planTier) }
    }
    /// displayMode == .tracked 时用这个模型名
    @Published var trackedModelName: String {
        didSet { UserDefaults.standard.set(trackedModelName, forKey: Keys.trackedModel) }
    }
    /// 无限额度样式(流光/量子流/呼吸/能量核心)
    @Published var weeklyUnlimitedStyle: WeeklyUnlimitedStyle {
        didSet { UserDefaults.standard.set(weeklyUnlimitedStyle.rawValue, forKey: Keys.weeklyStyle) }
    }
    /// 无限额度条颜色主题(紫蓝绿 / 红橙黄绿)
    @Published var unlimitedTheme: UnlimitedTheme {
        didSet { UserDefaults.standard.set(unlimitedTheme.rawValue, forKey: Keys.unlimitedTheme) }
    }
    /// 状态栏文字格式
    @Published var statusBarFormat: StatusBarFormat {
        didSet { UserDefaults.standard.set(statusBarFormat.rawValue, forKey: Keys.statusBarFormat) }
    }
    /// 额度显示方向(正向=剩余,反向=已用)
    @Published var quotaDisplay: QuotaDisplay {
        didSet { UserDefaults.standard.set(quotaDisplay.rawValue, forKey: Keys.quotaDisplay) }
    }
    /// 进度条颜色模式
    @Published var barColorMode: BarColorMode {
        didSet { UserDefaults.standard.set(barColorMode.rawValue, forKey: Keys.barColorMode) }
    }
    /// 状态栏图标预设
    @Published var statusBarIcon: StatusBarIcon {
        didSet { UserDefaults.standard.set(statusBarIcon.rawValue, forKey: Keys.statusBarIcon) }
    }
    /// 手动隐藏的模型(用户主动选择不显示某些模型,如不在套餐的)
    @Published var hiddenModels: Set<String> = []

    /// 周限额显示模式(用户手动覆盖学习的检测结果)
    /// - nil:自动,根据学习逻辑或 API status=3 判定
    /// - true:强制显示无限
    /// - false:强制显示受限(绿→红进度条)
    @Published var weeklyDisplayOverride: Bool? {
        didSet {
            if let v = weeklyDisplayOverride {
                UserDefaults.standard.set(v, forKey: Keys.weeklyOverride)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.weeklyOverride)
            }
        }
    }

    /// 订阅周期:月度 / 年度 / 终身 / 自定义
    @Published var subscriptionPeriod: SubscriptionPeriod {
        didSet {
            UserDefaults.standard.set(subscriptionPeriod.rawValue, forKey: Keys.subPeriod)
        }
    }
    /// 自定义周期文字(只在 subscriptionPeriod == .custom 时生效)
    @Published var customPeriodText: String {
        didSet {
            UserDefaults.standard.set(customPeriodText, forKey: Keys.subCustomText)
        }
    }
    /// 学到的"无限周额度"模型(当前 API key 下自动学习 + 持久化)
    @Published private(set) var unlimitedLearnedModels: Set<String> = []

    private var timer: Timer?
    private var weeklyUnlimitedEvidence: [String: WeeklyUnlimitedEvidence] = [:]

    static let shared = UsageStore()

    private enum Keys {
        static let refreshInterval = "refreshIntervalMinutes"
        static let displayMode = "displayMode"
        static let planTier = "planTier"
        static let trackedModel = "trackedModel"
        static let weeklyStyle = "weeklyUnlimitedStyle"
        static let unlimitedTheme = "unlimitedTheme"
        static let statusBarFormat = "statusBarFormat"
        static let quotaDisplay = "quotaDisplay"
        static let barColorMode = "barColorMode"
        static let statusBarIcon = "statusBarIcon"
        static let unlimitedLearned = "unlimitedLearnedModels"
        static let weeklyUnlimitedEvidence = "weeklyUnlimitedEvidence.v1"
        static let hiddenModels = "hiddenModels"
        static let subPeriod = "subscriptionPeriod"
        static let subCustomText = "customPeriodText"
        static let weeklyOverride = "weeklyDisplayOverride"
    }

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.refreshInterval) == nil {
            d.set(5.0, forKey: Keys.refreshInterval)
        }
        self.refreshIntervalMinutes = d.double(forKey: Keys.refreshInterval)

        let modeRaw = d.string(forKey: Keys.displayMode) ?? DisplayMode.minPercent.rawValue
        self.displayMode = DisplayMode(rawValue: modeRaw) ?? .minPercent

        let tierRaw = d.string(forKey: Keys.planTier) ?? PlanTier.unknown.rawValue
        self.planTier = PlanTier(rawValue: tierRaw) ?? .unknown

        self.trackedModelName = d.string(forKey: Keys.trackedModel) ?? "general"

        let styleRaw = d.string(forKey: Keys.weeklyStyle) ?? WeeklyUnlimitedStyle.shimmer.rawValue
        self.weeklyUnlimitedStyle = WeeklyUnlimitedStyle(rawValue: styleRaw) ?? .shimmer

        let themeRaw = d.string(forKey: Keys.unlimitedTheme) ?? UnlimitedTheme.violet.rawValue
        self.unlimitedTheme = UnlimitedTheme(rawValue: themeRaw) ?? .violet

        let fmtRaw = d.string(forKey: Keys.statusBarFormat) ?? StatusBarFormat.fiveHourAndWeekly.rawValue
        self.statusBarFormat = StatusBarFormat(rawValue: fmtRaw) ?? .fiveHourAndWeekly

        let iconRaw = d.string(forKey: Keys.statusBarIcon) ?? StatusBarIcon.whiteSmooth.rawValue
        self.statusBarIcon = StatusBarIcon(rawValue: iconRaw) ?? .whiteSmooth

        if let data = d.data(forKey: Keys.weeklyUnlimitedEvidence),
           let decoded = try? JSONDecoder().decode([String: WeeklyUnlimitedEvidence].self, from: data) {
            self.weeklyUnlimitedEvidence = decoded
        }

        if let arr = d.array(forKey: Keys.hiddenModels) as? [String] {
            self.hiddenModels = Set(arr)
        }

        let periodRaw = d.string(forKey: Keys.subPeriod) ?? SubscriptionPeriod.yearly.rawValue
        self.subscriptionPeriod = SubscriptionPeriod(rawValue: periodRaw) ?? .yearly
        self.customPeriodText = d.string(forKey: Keys.subCustomText) ?? ""

        if UserDefaults.standard.object(forKey: Keys.weeklyOverride) != nil {
            self.weeklyDisplayOverride = UserDefaults.standard.bool(forKey: Keys.weeklyOverride)
        }

        let qdRaw = d.string(forKey: Keys.quotaDisplay) ?? QuotaDisplay.used.rawValue
        self.quotaDisplay = QuotaDisplay(rawValue: qdRaw) ?? .used

        let bcmRaw = d.string(forKey: Keys.barColorMode) ?? BarColorMode.stepped.rawValue
        self.barColorMode = BarColorMode(rawValue: bcmRaw) ?? .stepped

        refreshUnlimitedLearnedModels()
    }

    // MARK: - API key

    var apiKeyConfigured: Bool { !(KeychainStore.load() ?? "").isEmpty }

    func saveAPIKey(_ key: String) {
        KeychainStore.save(key)
        refreshUnlimitedLearnedModels()
    }

    func clearAPIKey() {
        KeychainStore.delete()
        unlimitedLearnedModels = []
    }

    // MARK: - 派生

    /// 所有模型(按 model_name 排序,stable order)
    var models: [ModelUsage] {
        (usage?.modelRemains ?? []).sorted { $0.modelName < $1.modelName }
    }

    /// 可见模型(空窗口/没权限/手动隐藏的不展示)
    var visibleModels: [ModelUsage] {
        models.filter { model in
            // 1. 用户手动隐藏的模型
            if hiddenModels.contains(model.modelName) { return false }
            // 2. API 防护/套餐外占位模型:两个窗口都只有空信号
            if model.appearsUnavailable { return false }
            // 3. 5h 和 周 都 0% + 都是受限状态 → 没权限
            let intervalNoAccess = model.currentIntervalStatus == 1
                && model.currentIntervalRemainingPercent == 0
            let weeklyNoAccess = model.currentWeeklyStatus == 1
                && model.currentWeeklyRemainingPercent == 0
            return !(intervalNoAccess && weeklyNoAccess)
        }
    }

    /// 用于状态栏显示的剩余百分比 0~100
    var statusBarPercent: Int? {
        switch displayMode {
        case .minPercent:
            let ps = visibleModels.map { $0.currentIntervalRemainingPercent }
            return ps.min()
        case .tracked:
            return visibleModels.first(where: { $0.modelName == trackedModelName })?
                .currentIntervalRemainingPercent
        case .iconOnly:
            return nil
        }
    }

    /// 全部可见模型的 5h 是否都无限
    private var all5hUnlimited: Bool {
        let visible = visibleModels
        return !visible.isEmpty && visible.allSatisfy {
            isUnlimited($0, isWeekly: false)
        }
    }

    /// 全部可见模型的周是否都无限
    private var allWeeklyUnlimited: Bool {
        let visible = visibleModels
        return !visible.isEmpty && visible.allSatisfy {
            isUnlimited($0, isWeekly: true)
        }
    }

    /// 状态栏文字(图标后面直接显示,由 statusBarFormat 控制)
    /// ⚠ 只有 status != 1 才算真无限,percent==100 ≠ 无限(可能是"满"而已)
    var statusBarText: String {
        let visible = visibleModels
        guard apiKeyConfigured, !visible.isEmpty else { return "" }
        let min5h   = visible.map { $0.currentIntervalRemainingPercent }.min() ?? 100
        let minWkly = visible.map { $0.currentWeeklyRemainingPercent }.min() ?? 100
        let fiveUnlimited = all5hUnlimited
        let weekUnlimited = allWeeklyUnlimited

        switch statusBarFormat {
        case .iconOnly:
            return ""
        case .fiveHourOnly:
            if fiveUnlimited { return " ∞" }
            return " \(min5h)%"
        case .weeklyOnly:
            if weekUnlimited { return " ∞" }
            return " \(minWkly)%"
        case .usedPercent5h:
            if fiveUnlimited { return " 0%" }
            return " \(100 - min5h)%"
        case .usedPercentAll:
            let w = weekUnlimited ? "0%" : "\(100 - minWkly)%"
            if fiveUnlimited { return " 0%/\(w)" }
            return " \(100 - min5h)%/\(w)"
        case .fiveHourAndWeekly:
            if fiveUnlimited && weekUnlimited { return " ∞" }
            let w = weekUnlimited ? "∞" : "\(minWkly)%"
            if fiveUnlimited { return " ∞/\(w)" }
            return " \(min5h)%/\(w)"
        }
    }

    var statusBarSymbol: String { "chart.bar.doc.horizontal" }

    /// 颜色:绿→红平滑渐变(剩余越多越绿,越少越红)
    /// 100% → rgb(0.00, 0.71, 0.16) 官方绿
    ///   0% → rgb(0.90, 0.20, 0.20) 警告红
    func color(forPercent p: Int) -> Color {
        let ratio = Double(max(0, min(100, p))) / 100.0
        let r = 0.90 * (1.0 - ratio) + 0.00 * ratio
        let g = 0.20 * (1.0 - ratio) + 0.71 * ratio
        let b = 0.20 * (1.0 - ratio) + 0.16 * ratio
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - 无限额度学习

    /// 判断某个窗口是否无限
    /// - Parameters:
    ///   - model: 模型
    ///   - isWeekly: true=周窗口, false=5h 窗口
    func isUnlimited(_ model: ModelUsage, isWeekly: Bool) -> Bool {
        if isWeekly {
            // 用户手动覆盖
            if let ovr = weeklyDisplayOverride { return ovr }
            if model.appearsUnavailable { return false }
            // 学到的 + API 直接说无限(status != 1),但排除空占位模型
            if unlimitedLearnedModels.contains(model.modelName) { return true }
            if model.hasEmptyWeeklyQuotaSignal { return false }
            if model.currentWeeklyStatus != 1 { return true }
            return false
        } else {
            // 5h 窗口只信任 API status,但空窗口信号不是无限
            if model.hasEmptyIntervalQuotaSignal { return false }
            return model.currentIntervalStatus != 1
        }
    }

    // MARK: - 模型隐藏

    /// 手动隐藏模型(用户主动选择不显示某些模型,如不在套餐的)
    func hideModel(_ name: String) {
        hiddenModels.insert(name)
        UserDefaults.standard.set(Array(hiddenModels), forKey: Keys.hiddenModels)
    }

    func showModel(_ name: String) {
        hiddenModels.remove(name)
        UserDefaults.standard.set(Array(hiddenModels), forKey: Keys.hiddenModels)
    }

    func isHidden(_ name: String) -> Bool {
        hiddenModels.contains(name)
    }

    private struct WeeklyUnlimitedEvidence: Codable {
        var modelName: String
        var evidenceCount: Int
        var confirmed: Bool
        var lastIntervalStartTime: Int64
        var lastFiveHourUsageCount: Int64
        var lastFiveHourRemainingPercent: Int
        var lastWeeklyStartTime: Int64
        var lastWeeklyUsageCount: Int64
        var lastWeeklyRemainingPercent: Int
        var updatedAt: TimeInterval
    }

    private static let weeklyUnlimitedEvidenceThreshold = 2

    private func currentAPIKeyFingerprint() -> String? {
        let key = KeychainStore.load() ?? ""
        guard !key.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func evidenceStorageKey(apiKeyFingerprint: String, modelName: String) -> String {
        "\(apiKeyFingerprint):\(modelName)"
    }

    private func makeEvidence(from model: ModelUsage, confirmed: Bool = false, evidenceCount: Int = 0) -> WeeklyUnlimitedEvidence {
        WeeklyUnlimitedEvidence(
            modelName: model.modelName,
            evidenceCount: evidenceCount,
            confirmed: confirmed,
            lastIntervalStartTime: model.startTime,
            lastFiveHourUsageCount: model.currentIntervalUsageCount,
            lastFiveHourRemainingPercent: model.currentIntervalRemainingPercent,
            lastWeeklyStartTime: model.weeklyStartTime,
            lastWeeklyUsageCount: model.currentWeeklyUsageCount,
            lastWeeklyRemainingPercent: model.currentWeeklyRemainingPercent,
            updatedAt: Date().timeIntervalSince1970
        )
    }

    private func refreshUnlimitedLearnedModels() {
        guard let fingerprint = currentAPIKeyFingerprint() else {
            unlimitedLearnedModels = []
            return
        }
        let prefix = "\(fingerprint):"
        unlimitedLearnedModels = Set(weeklyUnlimitedEvidence.compactMap { key, evidence in
            key.hasPrefix(prefix) && evidence.confirmed ? evidence.modelName : nil
        })
    }

    private func saveWeeklyUnlimitedEvidence() {
        guard let data = try? JSONEncoder().encode(weeklyUnlimitedEvidence) else { return }
        UserDefaults.standard.set(data, forKey: Keys.weeklyUnlimitedEvidence)
        UserDefaults.standard.removeObject(forKey: Keys.unlimitedLearned)
        refreshUnlimitedLearnedModels()
    }

    private func weeklyShowsRealLimit(_ model: ModelUsage) -> Bool {
        model.currentWeeklyStatus == 1
            && (
                model.currentWeeklyTotalCount > 0
                || model.currentWeeklyUsageCount > 0
                || model.currentWeeklyRemainingPercent < 100
            )
    }

    /// 学习无限周额度模式:
    /// 同一 API key + 同一模型下,观察到 5h 窗口发生真实消耗,但周窗口连续不变,才推断周无限。
    /// 例外:用户手动覆盖(weeklyDisplayOverride != nil)时不学习
    func learnUnlimited() {
        // 用户已手动覆盖,不再学习
        guard weeklyDisplayOverride == nil else { return }
        guard let fingerprint = currentAPIKeyFingerprint() else { return }

        var changed = false
        for model in models {
            let key = evidenceStorageKey(apiKeyFingerprint: fingerprint, modelName: model.modelName)

            if model.appearsUnavailable {
                if weeklyUnlimitedEvidence.removeValue(forKey: key) != nil { changed = true }
                continue
            }

            if weeklyShowsRealLimit(model) {
                let replacement = makeEvidence(from: model)
                if weeklyUnlimitedEvidence[key]?.confirmed == true || weeklyUnlimitedEvidence[key]?.evidenceCount != 0 {
                    changed = true
                }
                weeklyUnlimitedEvidence[key] = replacement
                continue
            }

            guard model.currentIntervalStatus == 1, !model.hasEmptyIntervalQuotaSignal else {
                if weeklyUnlimitedEvidence[key] == nil {
                    weeklyUnlimitedEvidence[key] = makeEvidence(from: model)
                    changed = true
                }
                continue
            }

            guard var evidence = weeklyUnlimitedEvidence[key] else {
                weeklyUnlimitedEvidence[key] = makeEvidence(from: model)
                changed = true
                continue
            }

            let sameIntervalWindow = evidence.lastIntervalStartTime == model.startTime
            let sameWeeklyWindow = evidence.lastWeeklyStartTime == model.weeklyStartTime
            let fiveHourMoved = sameIntervalWindow
                && (
                    model.currentIntervalUsageCount > evidence.lastFiveHourUsageCount
                    || model.currentIntervalRemainingPercent < evidence.lastFiveHourRemainingPercent
                )
            let weeklyStayedFull = sameWeeklyWindow
                && model.currentWeeklyUsageCount == evidence.lastWeeklyUsageCount
                && model.currentWeeklyRemainingPercent == evidence.lastWeeklyRemainingPercent
                && model.currentWeeklyRemainingPercent == 100

            if fiveHourMoved && weeklyStayedFull {
                evidence.evidenceCount = min(
                    Self.weeklyUnlimitedEvidenceThreshold,
                    evidence.evidenceCount + 1
                )
                evidence.confirmed = evidence.evidenceCount >= Self.weeklyUnlimitedEvidenceThreshold
            }

            evidence.lastIntervalStartTime = model.startTime
            evidence.lastFiveHourUsageCount = model.currentIntervalUsageCount
            evidence.lastFiveHourRemainingPercent = model.currentIntervalRemainingPercent
            evidence.lastWeeklyStartTime = model.weeklyStartTime
            evidence.lastWeeklyUsageCount = model.currentWeeklyUsageCount
            evidence.lastWeeklyRemainingPercent = model.currentWeeklyRemainingPercent
            evidence.updatedAt = Date().timeIntervalSince1970

            weeklyUnlimitedEvidence[key] = evidence
            changed = true
        }
        if changed {
            saveWeeklyUnlimitedEvidence()
        }
    }

    // MARK: - Refresh

    func start() {
        restartTimer()
        Task { await refresh() }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func restartTimer() {
        timer?.invalidate()
        let seconds = max(60, refreshIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard apiKeyConfigured else {
            self.lastError = "未配置 API Key,点击「设置」填入"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let key = KeychainStore.load() ?? ""
            let data = try await APIClient.shared.fetchRemainsRaw(apiKey: key)
            self.rawJSON = Self.prettyPrint(data)
            do {
                let parsed = try JSONDecoder().decode(TokenPlanUsage.self, from: data)
                self.usage = parsed
                self.lastError = parsed.isSuccess ? nil : "API: \(parsed.baseResp.statusMsg)"
                if parsed.isSuccess {
                    self.lastUpdated = Date()
                    self.learnUnlimited()  // 每次成功刷新都尝试学习
                }

                // 如果当前 tracked 的模型名不在响应里,自动切回 minPercent 模式
                if displayMode == .tracked,
                   let list = parsed.modelRemains,
                   !list.contains(where: { $0.modelName == trackedModelName }) {
                    self.displayMode = .minPercent
                }
            } catch {
                self.lastError = "解码失败: \(error.localizedDescription)"
            }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    /// 健康检查:返回每一步的检查结果,用于设置面板显示
    struct HealthCheck: Equatable {
        var configSaved: Bool
        var tokenPresent: Bool
        var apiReachable: Bool
        var latencyMs: Int?
        var message: String

        static let allOK = HealthCheck(configSaved: true, tokenPresent: true, apiReachable: true, latencyMs: nil, message: "全部通过")
    }

    @MainActor
    func runHealthCheck() async -> HealthCheck {
        let token = KeychainStore.load() ?? ""
        let hasToken = !token.isEmpty
        let hasConfig = hasToken

        guard hasToken else {
            return HealthCheck(configSaved: false, tokenPresent: false,
                              apiReachable: false, latencyMs: nil,
                              message: "未配置 API Key")
        }

        let start = Date()
        do {
            _ = try await APIClient.shared.fetchRemainsRaw(apiKey: token)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            return HealthCheck(configSaved: true, tokenPresent: true,
                              apiReachable: true, latencyMs: elapsed,
                              message: "连接正常")
        } catch {
            return HealthCheck(configSaved: true, tokenPresent: true,
                              apiReachable: false, latencyMs: nil,
                              message: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private static func prettyPrint(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj,
                                                       options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: pretty, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return s
    }
}
