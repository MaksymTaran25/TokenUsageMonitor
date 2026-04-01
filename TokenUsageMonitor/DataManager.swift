// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation
import Combine
import WidgetKit
import OSLog

@MainActor
final class DataManager: ObservableObject {
    @Published var snapshot: UsageSnapshot = .placeholder
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isRateLimited = false
    @Published var windowHours: Int = SettingsManager.shared.windowHours

    private var timer: Timer?
    private var intervalObserver: AnyCancellable?
    private var consecutiveRateLimits = 0

    init() {
        loadFromFile()
        Task { await refresh() }
        startTimer()

        // Restart timer when user changes refresh interval
        intervalObserver = SettingsManager.shared.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.startTimer() }
            }
    }

    // MARK: - Title for menu bar

    var titleLabel: String {
        if let primary = snapshot.primaryBucket {
            return String(format: "%.0f%%", primary.utilization)
        }
        if isLoading && snapshot.lastUpdated == .distantPast { return "…" }
        return snapshot.formattedTotal
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        errorMessage = nil

        let hours = windowHours
        let tokenTask = Task.detached(priority: .background) {
            parseUsage(hours: hours)
        }
        let monthlyTask = Task.detached(priority: .background) {
            parseUsage(hours: Constants.Time.hours30d)
        }

        let fetchResult = await fetchBuckets()
        let tokenData = await tokenTask.value
        let monthlyData = await monthlyTask.value

        // Update rate-limited flag based on this fetch
        switch fetchResult {
        case .success(let buckets):
            Logger.data.info("Refresh succeeded — \(buckets.count) bucket(s)")
            consecutiveRateLimits = 0
            isRateLimited = false
            snapshot = makeSnapshot(buckets: buckets, tokenData: tokenData, monthlyData: monthlyData)
        case .rateLimited:
            consecutiveRateLimits += 1
            Logger.data.warning("Rate limited (consecutive: \(self.consecutiveRateLimits))")
            isRateLimited = true
            snapshot = makeSnapshot(buckets: snapshot.buckets, tokenData: tokenData, monthlyData: monthlyData)
            startTimer() // restart with backoff delay
        case .error(let msg):
            Logger.data.error("Refresh error: \(msg)")
            consecutiveRateLimits = 0
            isRateLimited = false
            errorMessage = msg
            snapshot = makeSnapshot(buckets: snapshot.buckets, tokenData: tokenData, monthlyData: monthlyData)
        }

        isLoading = false
        saveToFile(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setWindow(_ hours: Int) {
        Task { @MainActor in
            windowHours = hours
            SettingsManager.shared.windowHours = hours
            await refresh()
        }
    }

    // MARK: - OAuth fetch

    private enum FetchResult {
        case success([QuotaBucket])
        case rateLimited
        case error(String)
    }

    private func fetchBuckets() async -> FetchResult {
        do {
            let creds = try OAuthManager.shared.loadCredentials()
            let buckets = try await UsageAPI.fetchBuckets(accessToken: creds.accessToken)
            return .success(buckets)
        } catch CredentialError.notFound {
            return .error("Not signed in. Open the Claude app and complete login.")
        } catch UsageAPIError.rateLimited {
            return .rateLimited
        } catch UsageAPIError.unauthorized {
            // Claude Code CLI may have silently refreshed the token in the keychain.
            // Reload credentials and retry once before giving up.
            guard let fresh = try? OAuthManager.shared.loadCredentials(),
                  !fresh.isExpired else {
                return .error("Session expired. Relaunch the Claude app to refresh your credentials.")
            }
            do {
                let buckets = try await UsageAPI.fetchBuckets(accessToken: fresh.accessToken)
                return .success(buckets)
            } catch {
                return .error("Session expired. Relaunch the Claude app to refresh your credentials.")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func makeSnapshot(buckets: [QuotaBucket], tokenData: UsageSnapshot, monthlyData: UsageSnapshot) -> UsageSnapshot {
        let order = ["five_hour", "session", "seven_day", "weekly", "monthly"]
        let sorted = buckets.sorted {
            let li = order.firstIndex(of: $0.name) ?? 99
            let ri = order.firstIndex(of: $1.name) ?? 99
            return li < ri
        }
        return UsageSnapshot(
            buckets:         sorted,
            totalTokens:     tokenData.totalTokens,
            inputTokens:     tokenData.inputTokens,
            outputTokens:    tokenData.outputTokens,
            messageCount:    tokenData.messageCount,
            byModel:         tokenData.byModel,
            windowHours:     windowHours,
            lastUpdated:     Date(),
            monthlyTokens:   monthlyData.totalTokens,
            monthlyMessages: monthlyData.messageCount
        )
    }

    // MARK: - Persistence

    private func startTimer() {
        timer?.invalidate()
        let base = TimeInterval(SettingsManager.shared.refreshInterval)
        // Exponential backoff after consecutive 429s: 5m → 10m → 20m, capped at 30m
        let interval = consecutiveRateLimits > 0
            ? min(base * pow(2.0, Double(consecutiveRateLimits)), Constants.Refresh.maxBackoffSeconds)
            : base
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
    }

    private func saveToFile(_ s: UsageSnapshot) {
        guard let url  = sharedSnapshotURL(),
              let data = try? JSONEncoder().encode(s) else {
            Logger.data.error("Failed to encode or locate snapshot URL for saving")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            Logger.data.debug("Snapshot saved to shared container")
        } catch {
            Logger.data.error("Failed to write snapshot: \(error.localizedDescription)")
        }
    }

    private func loadFromFile() {
        guard let url   = sharedSnapshotURL(),
              let data  = try? Data(contentsOf: url),
              var saved = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        else {
            Logger.data.debug("No cached snapshot found — starting fresh")
            return
        }
        // Ensure correct sort even for cached data
        let order = ["five_hour", "session", "seven_day", "weekly", "monthly"]
        saved.buckets.sort {
            let li = order.firstIndex(of: $0.name) ?? 99
            let ri = order.firstIndex(of: $1.name) ?? 99
            return li < ri
        }
        snapshot = saved
    }
}
