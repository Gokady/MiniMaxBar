import Foundation

// 真实响应结构(已用真实 key 验证,2026-06-07)
//
// {
//   "model_remains": [
//     {
//       "start_time": 1780779600000,
//       "end_time": 1780797600000,
//       "remains_time": 1596,
//       "current_interval_total_count": 0,
//       "current_interval_usage_count": 0,
//       "model_name": "general",
//       "current_weekly_total_count": 0,
//       "current_weekly_usage_count": 0,
//       "weekly_start_time": 1780243200000,
//       "weekly_end_time": 1780848000000,
//       "weekly_remains_time": 50401596,
//       "current_interval_status": 1,
//       "current_interval_remaining_percent": 89,
//       "current_weekly_status": 3,
//       "current_weekly_remaining_percent": 100,
//       "interval_boost_permille": 2000,
//       "weekly_boost_permille": 2000
//     }
//   ],
//   "base_resp": {"status_code": 0, "status_msg": "success"}
// }

struct TokenPlanUsage: Codable {
    let baseResp: BaseResp
    let modelRemains: [ModelUsage]?

    enum CodingKeys: String, CodingKey {
        case baseResp = "base_resp"
        case modelRemains = "model_remains"
    }

    var isSuccess: Bool { baseResp.statusCode == 0 }
}

struct BaseResp: Codable {
    let statusCode: Int
    let statusMsg: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMsg = "status_msg"
    }
}

struct ModelUsage: Codable, Identifiable {
    let startTime: Int64          // ms
    let endTime: Int64            // ms
    let remainsTime: Int64        // seconds
    let currentIntervalTotalCount: Int64
    let currentIntervalUsageCount: Int64
    let modelName: String
    let currentWeeklyTotalCount: Int64
    let currentWeeklyUsageCount: Int64
    let weeklyStartTime: Int64
    let weeklyEndTime: Int64
    let weeklyRemainsTime: Int64
    let currentIntervalStatus: Int
    let currentIntervalRemainingPercent: Int
    let currentWeeklyStatus: Int
    let currentWeeklyRemainingPercent: Int
    let intervalBoostPermille: Int?
    let weeklyBoostPermille: Int?

    var id: String { modelName }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case remainsTime = "remains_time"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
        case modelName = "model_name"
        case currentWeeklyTotalCount = "current_weekly_total_count"
        case currentWeeklyUsageCount = "current_weekly_usage_count"
        case weeklyStartTime = "weekly_start_time"
        case weeklyEndTime = "weekly_end_time"
        case weeklyRemainsTime = "weekly_remains_time"
        case currentIntervalStatus = "current_interval_status"
        case currentIntervalRemainingPercent = "current_interval_remaining_percent"
        case currentWeeklyStatus = "current_weekly_status"
        case currentWeeklyRemainingPercent = "current_weekly_remaining_percent"
        case intervalBoostPermille = "interval_boost_permille"
        case weeklyBoostPermille = "weekly_boost_permille"
    }

    var startDate: Date { Date(timeIntervalSince1970: TimeInterval(startTime) / 1000) }
    var endDate:   Date { Date(timeIntervalSince1970: TimeInterval(endTime) / 1000) }
    var weeklyStartDate: Date { Date(timeIntervalSince1970: TimeInterval(weeklyStartTime) / 1000) }
    var weeklyEndDate:   Date { Date(timeIntervalSince1970: TimeInterval(weeklyEndTime) / 1000) }

    /// 0.0 ~ 1.0
    var fiveHourFraction: Double { max(0, min(1, Double(currentIntervalRemainingPercent) / 100)) }
    var weeklyFraction:   Double { max(0, min(1, Double(currentWeeklyRemainingPercent) / 100)) }

    /// API 会用 status=3 + total/usage=0 + remaining=100 表示一个"空窗口"。
    /// 对未开通/防护类模型(如 video)这不是无限额度,不能直接按 status != 1 显示无限。
    var hasEmptyIntervalQuotaSignal: Bool {
        currentIntervalStatus == 3
            && currentIntervalTotalCount == 0
            && currentIntervalUsageCount == 0
            && currentIntervalRemainingPercent == 100
    }

    var hasEmptyWeeklyQuotaSignal: Bool {
        currentWeeklyStatus == 3
            && currentWeeklyTotalCount == 0
            && currentWeeklyUsageCount == 0
            && currentWeeklyRemainingPercent == 100
    }

    /// 5h 和周额度都只有空信号时,通常是套餐外/防护占位模型,不应展示为无限。
    var appearsUnavailable: Bool {
        hasEmptyIntervalQuotaSignal && hasEmptyWeeklyQuotaSignal
    }

    /// 模型显示名(给 UI 用,目前只是首字母大写)
    var displayName: String {
        switch modelName.lowercased() {
        case "general": return "通用(文本/对话)"
        case "video":   return "视频生成"
        case "image":   return "图像生成"
        case "audio":   return "语音"
        case "speech":  return "语音合成"
        default:        return modelName.capitalized
        }
    }

    /// 状态码转可读文字(API 文档无定义,按观察推断)
    func statusText(_ code: Int) -> String {
        switch code {
        case 0: return "未启用"
        case 1: return "正常受限"
        case 2: return "受限"
        case 3: return "空/无限"   // 需要结合 total/usage 和另一个窗口判断
        default: return "状态 \(code)"
        }
    }
}
