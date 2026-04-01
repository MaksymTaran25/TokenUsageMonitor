// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation
import Combine
import ServiceManagement

/// Persists user preferences for which sections to display and in what order.
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    /// All configurable section IDs in default order.
    /// Only includes buckets the API actually returns + extra UI cards.
    static let allSectionIDs = ["five_hour", "seven_day", "monthly_card", "token_breakdown"]

    /// Display names for settings UI.
    static let sectionLabels: [String: String] = [
        "five_hour":        "Five hours",
        "seven_day":        "Seven days",
        "monthly_card":     "Monthly summary",
        "token_breakdown":  "Token breakdown"
    ]

    /// Available refresh intervals (in seconds).
    static let refreshOptions: [(label: String, seconds: Int)] = [
        ("1 min",  60),
        ("2 min",  120),
        ("5 min",  300),
        ("10 min", 600),
        ("15 min", 900),
    ]

    /// Ordered list of visible section IDs. Controls both visibility and order.
    @Published var visibleSections: [String] {
        didSet { save() }
    }

    /// Refresh interval in seconds.
    @Published var refreshInterval: Int {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: refreshKey)
        }
    }

    /// Last selected time window in hours (24, 168, or 720).
    @Published var windowHours: Int {
        didSet { UserDefaults.standard.set(windowHours, forKey: windowKey) }
    }

    /// Whether to send notifications when usage thresholds are crossed.
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: notifEnabledKey) }
    }

    /// Utilization % at which a warning notification fires.
    @Published var warningThreshold: Double {
        didSet { UserDefaults.standard.set(warningThreshold, forKey: warnThreshKey) }
    }

    /// Utilization % at which a critical notification fires.
    @Published var criticalThreshold: Double {
        didSet { UserDefaults.standard.set(criticalThreshold, forKey: critThreshKey) }
    }

    /// Whether the app launches automatically at login.
    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLoginService.shared.setEnabled(launchAtLogin) }
    }

    private let key            = "com.tokenusagemonitor.settings.v1"
    private let refreshKey     = "com.tokenusagemonitor.refreshInterval"
    private let windowKey      = "com.tokenusagemonitor.windowHours"
    private let notifEnabledKey = "com.tokenusagemonitor.notifEnabled"
    private let warnThreshKey  = "com.tokenusagemonitor.warnThreshold"
    private let critThreshKey  = "com.tokenusagemonitor.critThreshold"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String].self, from: data),
           !saved.isEmpty {
            self.visibleSections = saved.filter { Self.allSectionIDs.contains($0) }
        } else {
            self.visibleSections = Self.allSectionIDs
        }

        let savedInterval = UserDefaults.standard.integer(forKey: refreshKey)
        self.refreshInterval = savedInterval > 0 ? savedInterval : Constants.Refresh.defaultIntervalSeconds

        let savedWindow = UserDefaults.standard.integer(forKey: windowKey)
        self.windowHours = Constants.Time.validWindows.contains(savedWindow) ? savedWindow : Constants.Time.hours24

        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "com.tokenusagemonitor.notifEnabled")
        self.warningThreshold     = UserDefaults.standard.object(forKey: "com.tokenusagemonitor.warnThreshold")  as? Double ?? 80
        self.criticalThreshold    = UserDefaults.standard.object(forKey: "com.tokenusagemonitor.critThreshold") as? Double ?? 90
        self.launchAtLogin        = LaunchAtLoginService.shared.isEnabled
    }

    /// Returns whether a section ID is currently visible.
    func isVisible(_ id: String) -> Bool {
        visibleSections.contains(id)
    }

    /// Toggle visibility of a section.
    func toggle(_ id: String) {
        if let idx = visibleSections.firstIndex(of: id) {
            visibleSections.remove(at: idx)
        } else {
            let defaultOrder = Self.allSectionIDs
            let targetIdx = defaultOrder.firstIndex(of: id) ?? defaultOrder.count
            var insertAt = visibleSections.count
            for (i, existing) in visibleSections.enumerated() {
                let existingIdx = defaultOrder.firstIndex(of: existing) ?? defaultOrder.count
                if existingIdx > targetIdx {
                    insertAt = i
                    break
                }
            }
            visibleSections.insert(id, at: insertAt)
        }
    }

    /// Move a section from one index to another.
    func move(from source: IndexSet, to destination: Int) {
        visibleSections.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(visibleSections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
