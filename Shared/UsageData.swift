// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.
//
// Shared between the main app target and the widget extension.
// Keep this file free of any imports beyond Foundation.

import Foundation

// MARK: - Shared snapshot path

let snapshotFileName   = "widget-data.json"
let widgetBundleID     = "com.tokenusagemonitor.app.widget"

/// Returns the URL used by both the main app and widget to share snapshot data.
/// Uses the widget extension's own sandbox container, which:
/// - The widget can always access (it's its own container's Documents directory)
/// - The main app can access because it is not sandboxed (constructs the real path)
/// This avoids the need for App Groups, which require a paid Apple Developer account.
func sharedSnapshotURL() -> URL? {
    let fm = FileManager.default

    // Widget (sandboxed): homeDirectoryForCurrentUser is already the container root,
    // so Documents maps correctly to the widget's own container/Documents.
    if Bundle.main.bundleIdentifier == widgetBundleID {
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs.appendingPathComponent(snapshotFileName)
    }

    // Main app (unsandboxed): construct the real path to the widget's container.
    let home = fm.homeDirectoryForCurrentUser
    let url  = home.appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Documents")
    try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    return url.appendingPathComponent(snapshotFileName)
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

/// Parses an ISO 8601 date string, supporting both fractional and whole seconds.
func parseISO8601(_ string: String) -> Date? {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: string) { return d }
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: string)
}

func formatTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.0fk", Double(n) / 1_000) }
    return "\(n)"
}
