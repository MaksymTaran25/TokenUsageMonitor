// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation
import AppKit
import SwiftUI
import OSLog

struct AgentSession: Identifiable {
    let id: Int          // PID
    let directory: String

    var shortName: String    { URL(fileURLWithPath: directory).lastPathComponent }
    var displayPath: String  { directory.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

@MainActor
final class AgentWatchersService: ObservableObject {
    static let shared = AgentWatchersService()

    @Published private(set) var sessions: [AgentSession] = []

    @Published var isVisible = false {
        didSet {
            if isVisible {
                start()
                showOverlay()
            } else {
                stop()
                sessions = []
                hideOverlay()
            }
        }
    }

    private var timer: Timer?
    private var panel: NSPanel?

    // MARK: - Lifecycle

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Session detection

    private func poll() {
        Task.detached(priority: .background) {
            let found = Self.detectSessions()
            await MainActor.run { [weak self] in self?.sessions = found }
        }
    }

    private nonisolated static func detectSessions() -> [AgentSession] {
        let output = shell("/bin/ps", ["-eo", "pid,args"])
        let claudeLines = output.split(separator: "\n").filter { line in
            let lower = line.lowercased()
            return lower.contains("claude") &&
                   !lower.contains("/applications/claude.app/") &&  // Claude desktop app
                   !lower.contains("claude helper") &&               // Electron helpers
                   !lower.contains("disclaimer") &&                  // wrapper around claude-code binary
                   !lower.contains("tokenusagemonitor") &&
                   !lower.contains("grep")
        }
        Logger.data.info("Agent Watchers - \(claudeLines.count) match(es)")

        return claudeLines.compactMap { line -> AgentSession? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int(parts[0]) else { return nil }
            let cwd = workingDir(pid: pid)
            Logger.data.info("Agent Watchers PID \(pid) cwd: '\(cwd)'")
            guard !cwd.isEmpty, cwd != "/" else { return nil }
            return AgentSession(id: pid, directory: cwd)
        }
    }

    private nonisolated static func workingDir(pid: Int) -> String {
        let cwd = lsofCwd(pid: pid)
        if !cwd.isEmpty && cwd != "/" { return cwd }

        // claude changes its cwd to / at startup - fall back to parent process cwd
        let ppidOut = shell("/bin/ps", ["-p", "\(pid)", "-o", "ppid="])
        if let ppid = Int(ppidOut.trimmingCharacters(in: .whitespacesAndNewlines)), ppid > 1 {
            let parentCwd = lsofCwd(pid: ppid)
            if !parentCwd.isEmpty && parentCwd != "/" { return parentCwd }
        }
        return ""
    }

    private nonisolated static func lsofCwd(pid: Int) -> String {
        let out = shell("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])
        for line in out.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return ""
    }

    @discardableResult
    private nonisolated static func shell(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Session focus

    func focus(session: AgentSession) {
        Task.detached(priority: .userInitiated) {
            // Walk up PPID chain to find the terminal or GUI app that owns this session
            var pid = session.id
            var activated = false
            for _ in 0..<6 {
                let ppidStr = Self.shell("/bin/ps", ["-p", "\(pid)", "-o", "ppid="])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let ppid = Int(ppidStr), ppid > 1 else { break }
                let found: Bool = await MainActor.run {
                    guard let app = NSRunningApplication(processIdentifier: pid_t(ppid)),
                          let bundle = app.bundleIdentifier,
                          app.activationPolicy == .regular,
                          !bundle.contains("tokenusagemonitor") else { return false }
                    app.activate(options: .activateIgnoringOtherApps)
                    if let bundleURL = app.bundleURL {
                        NSWorkspace.shared.openApplication(
                            at: bundleURL,
                            configuration: NSWorkspace.OpenConfiguration()
                        ) { _, _ in }
                    }
                    return true
                }
                if found { activated = true; break }
                pid = ppid
            }
            if !activated {
                await MainActor.run {
                    NSWorkspace.shared.open(URL(fileURLWithPath: session.directory))
                }
            }
        }
    }

    // MARK: - Floating overlay

    private func showOverlay() {
        if let panel { panel.orderFront(nil); return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "Agent Watchers"
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.contentView = NSHostingView(rootView: AgentWatchersView())

        if let screen = NSScreen.main {
            p.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.maxX - 280,
                y: screen.visibleFrame.minY + 20
            ))
        }
        p.orderFront(nil)
        panel = p
    }

    private func hideOverlay() {
        panel?.close()
        panel = nil
    }
}
