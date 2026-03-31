// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var dm: DataManager
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            if showSettings {
                settingsPanel
            } else if let err = dm.errorMessage {
                errorView(err)
            } else if dm.snapshot.buckets.isEmpty && dm.isLoading {
                loadingView
            } else {
                if dm.isRateLimited {
                    rateLimitedBanner
                }
                // Render sections in user-configured order
                ForEach(Array(settings.visibleSections.enumerated()), id: \.element) { index, sectionID in
                    sectionView(for: sectionID)
                        .padding(.top, index > 0 ? 8 : 0)
                }
            }

            if !showSettings {
                windowPicker
                    .padding(.top, 12)
            }
            footer
                .padding(.top, 10)
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            AppIcon(size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Token Usage Monitor")
                    .font(.system(size: 13, weight: .semibold))
                if dm.snapshot.lastUpdated > .distantPast {
                    Text(dm.snapshot.lastUpdated, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    + Text(" ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if dm.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            }
        }
    }

    // MARK: - Dynamic section dispatcher

    @ViewBuilder
    private func sectionView(for id: String) -> some View {
        switch id {
        case "five_hour":
            if let bucket = dm.snapshot.buckets.first(where: { $0.name == "five_hour" }) {
                QuotaBarView(bucket: bucket)
            }
        case "seven_day":
            if let bucket = dm.snapshot.buckets.first(where: { $0.name == "seven_day" }) {
                QuotaBarView(bucket: bucket)
            }
        case "monthly_card":
            if dm.snapshot.monthlyTokens > 0 {
                monthlyCard
            }
        case "token_breakdown":
            if !dm.snapshot.byModel.isEmpty {
                tokenSection
            }
        default:
            // Any other API bucket (session, weekly, monthly, etc.)
            if let bucket = dm.snapshot.buckets.first(where: { $0.name == id }) {
                QuotaBarView(bucket: bucket)
            }
        }
    }

    // MARK: - Monthly summary card

    private var monthlyCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly summary")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.word.spacing")
                            .font(.system(size: 9))
                            .foregroundStyle(.purple)
                        Text(formatTokens(dm.snapshot.monthlyTokens))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    Text("\(dm.snapshot.monthlyMessages) messages")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("30d")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.secondary.opacity(0.1))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Token counts

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            Text("Token breakdown \u{00B7} \(windowLabel)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                ForEach(dm.snapshot.byModel) { model in
                    modelRow(model)
                }
            }

            // Input / Output summary
            HStack(spacing: 16) {
                tokenPill(icon: "arrow.up", value: formatTokens(dm.snapshot.inputTokens), color: .cyan)
                tokenPill(icon: "arrow.down", value: formatTokens(dm.snapshot.outputTokens), color: .mint)
                Spacer()
                Text("\(dm.snapshot.messageCount) msgs")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func modelRow(_ model: ModelSnapshot) -> some View {
        HStack {
            Circle()
                .fill(modelColor(model.shortName))
                .frame(width: 6, height: 6)
            Text(model.shortName)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(model.formattedTotal)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func modelColor(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("opus")   { return .purple }
        if lower.contains("sonnet") { return .cyan }
        if lower.contains("haiku")  { return .mint }
        return .gray
    }

    private func tokenPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Window picker

    private var windowPicker: some View {
        HStack(spacing: 6) {
            WindowTab(label: "24 h", isActive: dm.windowHours == 24) {
                dm.setWindow(24)
            }
            WindowTab(label: "7 days", isActive: dm.windowHours == 168) {
                dm.setWindow(168)
            }
            WindowTab(label: "30 days", isActive: dm.windowHours == 720) {
                dm.setWindow(720)
            }
        }
    }

    // MARK: - Settings panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visible sections")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            ReorderableList(settings: settings)

            let hiddenSections = SettingsManager.allSectionIDs.filter { !settings.isVisible($0) }
            if !hiddenSections.isEmpty {
                Divider().padding(.vertical, 4)

                Text("Hidden")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 3) {
                    ForEach(hiddenSections, id: \.self) { sectionID in
                        HiddenRow(
                            label: SettingsManager.sectionLabels[sectionID] ?? sectionID,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) { settings.toggle(sectionID) }
                            }
                        )
                    }
                }
            }

            Divider().padding(.vertical, 4)

            Text("Refresh interval")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(SettingsManager.refreshOptions, id: \.seconds) { option in
                    RefreshOptionButton(
                        label: option.label,
                        isActive: settings.refreshInterval == option.seconds
                    ) {
                        settings.refreshInterval = option.seconds
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 10)

            HStack(spacing: 0) {
                FooterButton(icon: "arrow.clockwise", label: "Refresh") {
                    Task { await dm.refresh() }
                }

                Divider()
                    .frame(height: 30)

                FooterButton(
                    icon: showSettings ? "xmark" : "gearshape",
                    label: showSettings ? "Close" : "Settings"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings.toggle()
                    }
                }

                Divider()
                    .frame(height: 30)

                FooterButton(icon: "power", label: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    // MARK: - States

    private var rateLimitedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("API rate limited — showing last known data")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.06))
        )
        .padding(.bottom, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading\u{2026}")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func errorView(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    // MARK: - Helpers

    private var windowLabel: String {
        switch dm.windowHours {
        case 24: return "24h"; case 168: return "7d"; default: return "30d"
        }
    }
}

// MARK: - Quota bar view (replaces ring gauges)

struct QuotaBarView: View {
    let bucket: QuotaBucket

    private var gradient: LinearGradient {
        switch bucket.status {
        case .normal:
            return LinearGradient(
                colors: [.teal, .cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .warning:
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .critical:
            return LinearGradient(
                colors: [.red, .pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var glowColor: Color {
        switch bucket.status {
        case .normal:   return .cyan
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(bucket.displayName)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(String(format: "%.0f%%", bucket.utilization))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(glowColor)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(gradient)
                        .frame(width: geo.size.width * min(bucket.utilization / 100, 1))
                        .shadow(color: glowColor.opacity(0.4), radius: 6, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.6), value: bucket.utilization)
                }
            }
            .frame(height: 6)

            if !bucket.resetLabel.isEmpty {
                Text(bucket.resetLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Hoverable window tab

struct WindowTab: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .primary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive
                              ? Color.accentColor.opacity(0.8)
                              : isHovered
                              ? Color.primary.opacity(0.08)
                              : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Hoverable footer button

struct FooterButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.primary.opacity(isHovered ? 1.0 : 0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - App icon (menu bar popover)

struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: .purple.opacity(0.4), radius: size * 0.15)
    }
}

// MARK: - Reorderable list (tap to select, tap to place)

struct ReorderableList: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 3) {
            ForEach(settings.visibleSections, id: \.self) { sectionID in
                let isSelected = selectedID == sectionID
                HStack(spacing: 8) {
                    // Position indicator
                    Image(systemName: isSelected ? "arrow.up.arrow.down" : "line.3.horizontal")
                        .font(.system(size: isSelected ? 9 : 10, weight: .medium))
                        .foregroundColor(isSelected ? .cyan : Color.primary.opacity(0.3))
                        .frame(width: 14)

                    Text(SettingsManager.sectionLabels[sectionID] ?? sectionID)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .cyan : .primary)

                    Spacer()

                    Button {
                        selectedID = nil
                        withAnimation(.easeInOut(duration: 0.2)) { settings.toggle(sectionID) }
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.cyan.opacity(0.08) : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap(sectionID)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedID)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: settings.visibleSections)
    }

    private func handleTap(_ tappedID: String) {
        if let selected = selectedID {
            if selected == tappedID {
                // Deselect
                selectedID = nil
            } else {
                // Swap positions
                guard let fromIdx = settings.visibleSections.firstIndex(of: selected),
                      let toIdx = settings.visibleSections.firstIndex(of: tappedID)
                else { return }
                selectedID = nil
                settings.move(
                    from: IndexSet(integer: fromIdx),
                    to: toIdx > fromIdx ? toIdx + 1 : toIdx
                )
            }
        } else {
            // Select
            selectedID = tappedID
        }
    }
}

// MARK: - Hidden section row

// MARK: - Refresh interval button

struct RefreshOptionButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .primary.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive
                              ? Color.accentColor.opacity(0.8)
                              : isHovered
                              ? Color.primary.opacity(0.08)
                              : Color.primary.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct HiddenRow: View {
    let label: String
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
    }
}
