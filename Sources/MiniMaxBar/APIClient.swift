import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.minimaxi.com")!
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: cfg)
    }

    enum APIError: Error, LocalizedError {
        case noAPIKey
        case transport(String)
        case http(Int)
        case api(statusCode: Int, message: String)
        case decode(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "未配置 API Key,请在设置中填入"
            case .transport(let m): return "网络错误:\(m)"
            case .http(let code): return "HTTP \(code)"
            case .api(let c, let m): return "API 错误(\(c)):\(m)"
            case .decode(let m): return "解析响应失败:\(m)"
            }
        }
    }

    /// 调用 /v1/token_plan/remains,返回原始 Data(让上层按需解析)
    func fetchRemainsRaw(apiKey: String) async throws -> Data {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }

        let url = baseURL.appendingPathComponent("/v1/token_plan/remains")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(0)
        }

        if http.statusCode != 200 {
            // 尝试从 body 里读出 base_resp 错误信息
            if let err = try? JSONDecoder().decode(TokenPlanUsage.self, from: data),
               !err.isSuccess {
                throw APIError.api(statusCode: err.baseResp.statusCode,
                                   message: err.baseResp.statusMsg)
            }
            throw APIError.http(http.statusCode)
        }
        return data
    }
}
