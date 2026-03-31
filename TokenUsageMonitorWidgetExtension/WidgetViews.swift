// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI
import WidgetKit

// MARK: - Entry view dispatcher

struct ClaudeWidgetEntryView: View {
    var entry: UsageEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot)
        case .systemLarge:  LargeWidgetView(snapshot: entry.snapshot)
        default:            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct WeeklyWidgetEntryView: View {
    var entry: UsageEntry

    var body: some View {
        SmallWeeklyWidgetView(snapshot: entry.snapshot)
    }
}

// MARK: - Small widget — hero percentage + bar for primary bucket

struct SmallWidgetView: View {
    var snapshot: UsageSnapshot

    private var bucket: QuotaBucket? { snapshot.primaryBucket }

    private var accentColor: Color {
        guard let bucket else { return .cyan }
        return statusColor(bucket.status)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Current usage")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()

            if let bucket {
                Text(String(format: "%.0f%%", bucket.utilization))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(bucket.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)

                WidgetProgressBar(value: bucket.utilization / 100, status: bucket.status)
                    .padding(.top, 8)

                if !bucket.resetLabel.isEmpty {
                    Text(bucket.resetLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small widget (Seven days) — shows seven_day bucket

struct SmallWeeklyWidgetView: View {
    var snapshot: UsageSnapshot

    private var bucket: QuotaBucket? {
        snapshot.buckets.first { $0.name == "seven_day" || $0.name == "weekly" }
    }

    private var accentColor: Color {
        guard let bucket else { return .cyan }
        return statusColor(bucket.status)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Weekly usage")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()

            if let bucket {
                Text(String(format: "%.0f%%", bucket.utilization))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(bucket.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)

                WidgetProgressBar(value: bucket.utilization / 100, status: bucket.status)
                    .padding(.top, 8)

                if !bucket.resetLabel.isEmpty {
                    Text(bucket.resetLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium widget — all buckets + token summary

struct MediumWidgetView: View {
    var snapshot: UsageSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: quota bars
            VStack(alignment: .leading, spacing: 0) {
                Text("Rate limits")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                if snapshot.buckets.isEmpty {
                    Spacer()
                    Text("No quota data")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(snapshot.buckets.prefix(3)) { bucket in
                        WidgetBucketRow(bucket: bucket)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)

            // Right: token breakdown
            VStack(alignment: .leading, spacing: 0) {
                Text("Token breakdown \u{00B7} \(windowLabel(snapshot.windowHours))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                if snapshot.byModel.isEmpty {
                    Spacer()
                    Text("No activity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(snapshot.byModel.prefix(3)) { model in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(modelColor(model.shortName))
                                .frame(width: 5, height: 5)
                            Text(model.shortName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                            Text(model.formattedTotal)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 4)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    tokenMini(icon: "arrow.up", value: formatTokens(snapshot.inputTokens), color: .cyan)
                    tokenMini(icon: "arrow.down", value: formatTokens(snapshot.outputTokens), color: .mint)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

// MARK: - Large widget — full dashboard with all buckets + detailed breakdown

struct LargeWidgetView: View {
    var snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("Token Usage Monitor")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(windowLabel(snapshot.windowHours))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.bottom, 14)

            // Quota section
            if snapshot.buckets.isEmpty {
                Text("No quota data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            } else {
                ForEach(snapshot.buckets) { bucket in
                    LargeWidgetBucketRow(bucket: bucket)
                        .padding(.bottom, 10)
                }
            }

            // Separator
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 6)

            // Token breakdown
            Text("Token breakdown")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            if snapshot.byModel.isEmpty {
                Text("No activity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.byModel) { model in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modelColor(model.shortName))
                            .frame(width: 6, height: 6)
                        Text(model.shortName)
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text(model.formattedTotal)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\u{00B7} \(model.messageCount) msg")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                    .padding(.bottom, 4)
                }
            }

            Spacer(minLength: 0)

            // Footer: input/output summary
            HStack(spacing: 14) {
                tokenMini(icon: "arrow.up", value: formatTokens(snapshot.inputTokens), color: .cyan)
                tokenMini(icon: "arrow.down", value: formatTokens(snapshot.outputTokens), color: .mint)
                Spacer()
                Text("\(snapshot.messageCount) messages")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

// MARK: - Large widget bucket row (more detailed than medium)

struct LargeWidgetBucketRow: View {
    let bucket: QuotaBucket

    private var color: Color { statusColor(bucket.status) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(bucket.displayName)
                    .font(.system(size: 11, weight: .medium))
                if !bucket.resetLabel.isEmpty {
                    Text(bucket.resetLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", bucket.utilization))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            WidgetProgressBar(value: bucket.utilization / 100, status: bucket.status)
        }
    }
}

// MARK: - Shared widget components

struct WidgetProgressBar: View {
    let value: Double
    let status: UsageStatus

    private var gradient: LinearGradient {
        switch status {
        case .normal:
            return LinearGradient(colors: [.teal, .cyan], startPoint: .leading, endPoint: .trailing)
        case .warning:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .critical:
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(gradient)
                    .frame(width: geo.size.width * min(value, 1))
            }
        }
        .frame(height: 5)
    }
}

struct WidgetBucketRow: View {
    let bucket: QuotaBucket

    private var color: Color { statusColor(bucket.status) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(bucket.displayName)
                    .font(.system(size: 10))
                Spacer()
                Text(String(format: "%.0f%%", bucket.utilization))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            WidgetProgressBar(value: bucket.utilization / 100, status: bucket.status)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - App icon for widgets (visible on any background)

struct WidgetAppIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer gradient border — fully opaque so it's visible on any widget background
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.2, blue: 0.9),
                            Color(red: 0.6, green: 0.15, blue: 0.7),
                            Color(red: 0.85, green: 0.25, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Inner dark face — opaque black-ish, not semi-transparent
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Color(red: 0.1, green: 0.08, blue: 0.14))
                .frame(width: size * 0.76, height: size * 0.76)

            // Icon — bright gradient so it pops on the dark face
            Image(systemName: "speedometer")
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.9, blue: 0.95),
                            Color(red: 0.6, green: 0.4, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.system(size: size * 0.38, weight: .semibold))
        }
    }
}

// MARK: - Shared helpers

private func tokenMini(icon: String, value: String, color: Color) -> some View {
    HStack(spacing: 3) {
        Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundStyle(color)
        Text(value)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}

private func statusColor(_ status: UsageStatus) -> Color {
    switch status {
    case .normal:   return .cyan
    case .warning:  return .orange
    case .critical: return .red
    }
}

private func modelColor(_ name: String) -> Color {
    let lower = name.lowercased()
    if lower.contains("opus")   { return .purple }
    if lower.contains("sonnet") { return .cyan }
    if lower.contains("haiku")  { return .mint }
    return .gray
}

private func windowLabel(_ hours: Int) -> String {
    switch hours {
    case 24: return "24h"
    case 168: return "7d"
    default: return "30d"
    }
}
