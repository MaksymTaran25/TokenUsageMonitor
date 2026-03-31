// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.
//
// Fetches quota utilization from Anthropic's OAuth usage endpoint.
//
// Endpoint: GET https://api.anthropic.com/api/oauth/usage
// This endpoint is not publicly documented by Anthropic. It is the same
// endpoint used by the Claude.ai web dashboard to display usage limits.
//
// DISCLAIMER: This is an unofficial integration. Use at your own risk.
// This app is not affiliated with or endorsed by Anthropic.

import Foundation

enum UsageAPIError: Error, LocalizedError {
    case unauthorized
    case rateLimited
    case httpError(Int)
    case noData
    case parseError

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Token expired. Please relaunch the Claude app to refresh your session."
        case .rateLimited:
            return nil // handled gracefully in UI as 100% usage
        case .httpError(let code):
            return "Server returned HTTP \(code)."
        case .noData:
            return "No usage data returned."
        case .parseError:
            return "Could not parse usage response."
        }
    }
}

struct UsageAPI {
    private static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetchBuckets(accessToken: String) async throws -> [QuotaBucket] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20",       forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.setValue(
            "ClaudeTokenMonitor/1.0.0 (https://github.com/open-source-disclaimer)",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw UsageAPIError.parseError }

        switch http.statusCode {
        case 200:       break
        case 401, 403:  throw UsageAPIError.unauthorized
        case 429:       throw UsageAPIError.rateLimited
        default:        throw UsageAPIError.httpError(http.statusCode)
        }

        return try parse(data)
    }

    // MARK: - Response parsing

    private static func parse(_ data: Data) throws -> [QuotaBucket] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else {
            throw UsageAPIError.parseError
        }

        var buckets: [QuotaBucket] = []

        if let dict = obj as? [String: Any] {
            for (key, value) in dict {
                if let d = value as? [String: Any], let b = makeBucket(name: key, d: d) {
                    buckets.append(b)
                }
            }
        } else if let array = obj as? [[String: Any]] {
            for item in array {
                let name = item["type"] as? String ?? item["name"] as? String ?? "limit"
                if let b = makeBucket(name: name, d: item) {
                    buckets.append(b)
                }
            }
        }

        if buckets.isEmpty { throw UsageAPIError.noData }

        // Sort: shortest window first → longest
        let order = ["five_hour", "session", "seven_day", "weekly", "monthly"]
        return buckets.sorted {
            let li = order.firstIndex(of: $0.name) ?? 99
            let ri = order.firstIndex(of: $1.name) ?? 99
            return li < ri
        }
    }

    private static func makeBucket(name: String, d: [String: Any]) -> QuotaBucket? {
        let utilization: Double
        if let v = d["utilization"] as? Double      { utilization = v }
        else if let v = d["utilization"] as? Int    { utilization = Double(v) }
        else                                        { return nil }

        var resetsAt: Date? = nil
        if let s = d["resets_at"] as? String {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetsAt = fmt.date(from: s)
            if resetsAt == nil {
                fmt.formatOptions = [.withInternetDateTime]
                resetsAt = fmt.date(from: s)
            }
        }

        return QuotaBucket(name: name, utilization: utilization, resetsAt: resetsAt)
    }
}
