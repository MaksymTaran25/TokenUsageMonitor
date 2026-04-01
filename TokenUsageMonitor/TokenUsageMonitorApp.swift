// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI

@main
struct TokenUsageMonitorApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var theme       = ThemeManager.shared

    init() {
        NotificationService.shared.setup()
        Task { await UpdateService.shared.checkForUpdates() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dataManager)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: {
                    let img = NSImage(named: "AppIcon") ?? NSImage()
                    img.size = NSSize(width: 18, height: 18)
                    return img
                }())
                Text(dataManager.titleLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(menuBarStatusColor)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarStatusColor: Color {
        guard let status = dataManager.snapshot.primaryBucket?.status else { return .primary }
        switch status {
        case .normal:   return theme.normalGlow
        case .warning:  return theme.warningGlow
        case .critical: return theme.criticalGlow
        }
    }
}
