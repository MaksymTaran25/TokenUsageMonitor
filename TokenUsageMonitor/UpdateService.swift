// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation
import AppKit
import OSLog

struct AppcastEntry: Decodable {
    let version: String
    let url: URL
}

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published private(set) var availableUpdate: AppcastEntry?
    @Published private(set) var isInstalling = false
    @Published private(set) var installError: String?

    private let feedURL = URL(string: "https://raw.githubusercontent.com/MaksymTaran25/TokenUsageMonitor/main/docs/appcast.json")!

    // MARK: - Check

    func checkForUpdates() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            let entry = try JSONDecoder().decode(AppcastEntry.self, from: data)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            if isNewer(entry.version, than: current) {
                availableUpdate = entry
                Logger.api.info("Update available: \(entry.version)")
            } else {
                Logger.api.debug("Already up to date: \(current)")
            }
        } catch {
            Logger.api.debug("Update check failed: \(error)")
        }
    }

    // MARK: - Install

    func downloadAndInstall(_ entry: AppcastEntry) async {
        isInstalling = true
        installError = nil
        defer { isInstalling = false }

        do {
            // 1. Download DMG
            let tmpDMG = FileManager.default.temporaryDirectory
                .appendingPathComponent("TokenUsageMonitor-\(entry.version).dmg")
            try? FileManager.default.removeItem(at: tmpDMG)

            let (downloadedURL, _) = try await URLSession.shared.download(from: entry.url)
            try FileManager.default.moveItem(at: downloadedURL, to: tmpDMG)

            // 2. Mount DMG
            let mountPoint = NSTemporaryDirectory() + "TokenUsageMonitorUpdate"
            try? FileManager.default.removeItem(atPath: mountPoint)
            try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

            let mountTask = Process()
            mountTask.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            mountTask.arguments = ["attach", tmpDMG.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint]
            mountTask.standardOutput = Pipe()
            mountTask.standardError = Pipe()
            try mountTask.run()
            mountTask.waitUntilExit()

            guard mountTask.terminationStatus == 0 else {
                throw UpdateError.mountFailed
            }

            let newAppPath = mountPoint + "/TokenUsageMonitor.app"
            guard FileManager.default.fileExists(atPath: newAppPath) else {
                throw UpdateError.appNotFoundInDMG
            }

            // 3. Write a script that waits for us to quit, copies the new app, then relaunches
            let currentApp  = Bundle.main.bundleURL.path
            let installDir  = Bundle.main.bundleURL.deletingLastPathComponent().path
            let scriptPath  = NSTemporaryDirectory() + "token-usage-update.sh"

            let script = """
            #!/bin/bash
            sleep 1.5
            if cp -Rf "\(newAppPath)" "\(installDir)/"; then
                /usr/bin/hdiutil detach "\(mountPoint)" -quiet 2>/dev/null
                open "\(currentApp)"
            else
                open "\(mountPoint)"
            fi
            """

            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

            // 4. Kick off the script and quit
            let scriptTask = Process()
            scriptTask.executableURL = URL(fileURLWithPath: "/bin/bash")
            scriptTask.arguments = [scriptPath]
            try scriptTask.run()

            Logger.api.info("Update script started - quitting to complete install")
            NSApp.terminate(nil)

        } catch {
            installError = error.localizedDescription
            Logger.api.error("Update install failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.split(separator: ".").compactMap { Int($0) }
        let bv = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(av.count, bv.count) {
            let ai = i < av.count ? av[i] : 0
            let bi = i < bv.count ? bv[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }

    enum UpdateError: LocalizedError {
        case mountFailed
        case appNotFoundInDMG

        var errorDescription: String? {
            switch self {
            case .mountFailed:      return "Failed to mount update package"
            case .appNotFoundInDMG: return "App not found in update package"
            }
        }
    }
}
