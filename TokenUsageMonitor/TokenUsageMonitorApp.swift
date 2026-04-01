// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI

@main
struct TokenUsageMonitorApp: App {
    @StateObject private var dataManager = DataManager()

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
            }
        }
        .menuBarExtraStyle(.window)
    }
}
