// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.
//
// Shared between the main app target and the widget extension.
// Keep this file free of any imports beyond Foundation.

import Foundation

// MARK: - App Group constants

let appGroupID       = "group.com.tokenusagemonitor"
let snapshotFileName = "widget-data.json"

/// Returns the shared container URL for both sandboxed (widget) and
/// non-sandboxed (main app) processes.
/// - Sandboxed: uses the App Group container via FileManager API.
/// - Non-sandboxed: constructs the Group Containers path directly.
func sharedContainerURL() -> URL? {
    // Works for sandboxed processes (widget extension)
    if let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) { return url }

    // Fallback for non-sandboxed main app
    let home = FileManager.default.homeDirectoryForCurrentUser
    let url  = home.appendingPathComponent("Library/Group Containers/\(appGroupID)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func sharedSnapshotURL() -> URL? {
    sharedContainerURL()?.appendingPathComponent(snapshotFileName)
}

// MARK: - Quota bucket (from OAuth API)

struct QuotaBucket: Codable, Identifiable {
    var id: String { name }
    var name: String          // "session", "weekly", etc.
    var utilization: Double   // 0-100
    var resetsAt: Date?

    var displayName: String {
        switch name {
        case "five_hour":  return "Five hours"
        case "seven_day":  return "Seven days"
        case "session":    return "Session"
        case "weekly":     return "Weekly"
        case "monthly":    return "Monthly"
        default:           return name.prefix(1).uppercased() + name.dropFirst()
        }
    }

    var status: UsageStatus {
        if utilization >= 85 { return .critical }
        if utilization >= 60 { return .warning }
        return .normal
    }

    var resetLabel: String {
        guard let resetsAt else { return "" }
        let seconds = Int(resetsAt.timeIntervalSinceNow)
        guard seconds > 0 else { return "Resetting soon" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "Resets in \(h)h \(m)m" }
        return "Resets in \(m)m"
    }
}

enum UsageStatus: String, Codable {
    case normal, warning, critical
}

// MARK: - Token counts (from JSONL files)

struct ModelSnapshot: Codable, Identifiable {
    var id: String { model }
    var model: String
    var totalTokens: Int
    var inputTokens: Int
    var outputTokens: Int
    var messageCount: Int

    var formattedTotal: String { formatTokens(totalTokens) }

    var shortName: String {
        let lower = model.lowercased()
        for family in ["opus", "sonnet", "haiku"] {
            guard lower.contains(family) else { continue }
            let after = lower.components(separatedBy: family).last ?? ""
            let digits = after
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                .split(separator: "-")
                .filter { $0.allSatisfy(\.isNumber) }
                .prefix(2)
            if digits.count >= 2 {
                return "\(family.capitalized) \(digits[0]).\(digits[1])"
            }
            return family.capitalized
        }
        return model
    }
}

// MARK: - Combined snapshot

struct UsageSnapshot: Codable {
    var buckets: [QuotaBucket]        // from OAuth API
    var totalTokens: Int              // from JSONL
    var inputTokens: Int
    var outputTokens: Int
    var messageCount: Int
    var byModel: [ModelSnapshot]
    var windowHours: Int
    var lastUpdated: Date
    var monthlyTokens: Int            // always 30-day total from JSONL
    var monthlyMessages: Int

    var primaryBucket: QuotaBucket? { buckets.first { $0.name == "session" } ?? buckets.first }
    var formattedTotal: String      { formatTokens(totalTokens) }

    static let placeholder = UsageSnapshot(
        buckets: [],
        totalTokens: 0, inputTokens: 0, outputTokens: 0,
        messageCount: 0, byModel: [], windowHours: 24,
        lastUpdated: .distantPast,
        monthlyTokens: 0, monthlyMessages: 0
    )
}

// MARK: - Helpers

func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.0fk", Double(n) / 1_000) }
    return "\(n)"
}
