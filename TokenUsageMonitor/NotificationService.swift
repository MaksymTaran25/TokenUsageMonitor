// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import UserNotifications
import OSLog

final class NotificationService {
    static let shared = NotificationService()

    // Tracks which (bucket + level) combos have already fired to avoid spamming
    private var fired: Set<String> = []

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { Logger.data.error("Notification permission error: \(error)") }
            Logger.data.info("Notifications permission granted: \(granted)")
        }
    }

    func check(buckets: [QuotaBucket], warningAt: Double, criticalAt: Double) {
        for bucket in buckets {
            let wKey = "\(bucket.name)-warn"
            let cKey = "\(bucket.name)-crit"

            if bucket.utilization >= criticalAt {
                if !fired.contains(cKey) {
                    send(
                        title: "\(bucket.displayName) at \(Int(bucket.utilization))%",
                        body: "You may hit your rate limit soon.",
                        id: cKey
                    )
                    fired.insert(cKey)
                    fired.remove(wKey)
                }
            } else if bucket.utilization >= warningAt {
                if !fired.contains(wKey) {
                    send(
                        title: "\(bucket.displayName) at \(Int(bucket.utilization))%",
                        body: "Usage is getting high.",
                        id: wKey
                    )
                    fired.insert(wKey)
                }
            } else {
                // Usage dropped back down - reset so the next spike notifies again
                fired.remove(wKey)
                fired.remove(cKey)
            }
        }
    }

    private func send(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil)
        ) { error in
            if let error { Logger.data.error("Failed to send notification: \(error)") }
        }
    }
}
