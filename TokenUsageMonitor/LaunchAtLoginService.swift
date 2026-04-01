// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import ServiceManagement
import OSLog

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {
            Logger.data.error("Launch at login toggle failed: \(error)")
        }
    }
}
