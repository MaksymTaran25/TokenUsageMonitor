// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import WidgetKit
import SwiftUI
import OSLog

private let widgetLogger = Logger(subsystem: "com.tokenusagemonitor.app", category: "Widget")

// MARK: - Timeline provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(UsageEntry(date: .now, snapshot: buildSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let snapshot = buildSnapshot()
        let entry    = UsageEntry(date: .now, snapshot: snapshot)
        // Reload every minute so the widget stays current
        let next     = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Builds the freshest possible snapshot by combining:
    /// - Cached bucket/quota data from the shared container (written by the main app)
    /// - Freshly parsed JSONL token data read directly from ~/.claude/projects/
    private func buildSnapshot() -> UsageSnapshot {
        let cached  = loadCachedSnapshot()
        let hours   = cached.windowHours > 0 ? cached.windowHours : 24
        let fresh   = parseUsage(hours: hours)

        // If JSONL parsing found data, merge with cached bucket info
        if fresh.totalTokens > 0 || !fresh.byModel.isEmpty {
            widgetLogger.info("Widget refresh: fresh JSONL data merged with \(cached.buckets.count) cached bucket(s)")
            return UsageSnapshot(
                buckets:         cached.buckets,
                totalTokens:     fresh.totalTokens,
                inputTokens:     fresh.inputTokens,
                outputTokens:    fresh.outputTokens,
                messageCount:    fresh.messageCount,
                byModel:         fresh.byModel,
                windowHours:     hours,
                lastUpdated:     cached.lastUpdated,
                monthlyTokens:   cached.monthlyTokens,
                monthlyMessages: cached.monthlyMessages
            )
        }
        widgetLogger.debug("Widget refresh: no fresh JSONL data, using cached snapshot")
        return cached
    }

    private func loadCachedSnapshot() -> UsageSnapshot {
        guard let url      = sharedSnapshotURL(),
              let data     = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}

// MARK: - Timeline entry

struct UsageEntry: TimelineEntry {
    var date: Date
    var snapshot: UsageSnapshot
}

// MARK: - Main widget (current usage - small/medium/large)

struct TokenUsageMonitorWidget: Widget {
    let kind = "TokenUsageMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClaudeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Usage")
        .description("Shows your current rate limit usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Weekly widget (seven-day usage - small only)

struct WeeklyUsageWidget: Widget {
    let kind = "WeeklyUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeeklyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Usage")
        .description("Shows your 7-day rate limit usage.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget bundle

@main
struct TokenUsageMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        TokenUsageMonitorWidget()
        WeeklyUsageWidget()
    }
}
