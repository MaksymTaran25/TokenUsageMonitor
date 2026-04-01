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
        didSet { isVisible ? showOverlay() : hideOverlay() }
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
        return output.split(separator: "\n").compactMap { line -> AgentSession? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let pid = Int(parts[0])
            else { return nil }
            let args = parts[1].lowercased()
            guard args.contains("claude"),
                  !args.contains("tokenusagemonitor")
            else { return nil }
            let cwd = workingDir(pid: pid)
            guard !cwd.isEmpty, cwd != "/" else { return nil }
            return AgentSession(id: pid, directory: cwd)
        }
    }

    private nonisolated static func workingDir(pid: Int) -> String {
        let out = shell("/usr/sbin/lsof", ["-p", "\(pid)", "-d", "cwd", "-Fn"])
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
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
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
