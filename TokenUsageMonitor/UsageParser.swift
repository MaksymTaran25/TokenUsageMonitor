// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation

private let claudeProjectsDir = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/projects")

// MARK: - Public entry point

func parseUsage(hours: Int, directory: URL? = nil) -> UsageSnapshot {
    let dir    = directory ?? claudeProjectsDir
    let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
    var entries: [RawEntry] = []

    let fm = FileManager.default
    guard let enumerator = fm.enumerator(
        at: dir,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: .skipsHiddenFiles
    ) else {
        return .placeholder
    }

    for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "jsonl" else { continue }

        // Skip files whose mtime predates the window by more than 1h
        if let mtime = try? fileURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate, mtime < cutoff.addingTimeInterval(-3600) {
            continue
        }

        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

        for line in text.components(separatedBy: "\n") {
            if let entry = parseEntry(line, cutoff: cutoff) {
                entries.append(entry)
            }
        }
    }

    return aggregate(entries: entries, hours: hours)
}

// MARK: - Private helpers

private struct RawEntry {
    var model: String
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationTokens: Int
    var cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

private func parseEntry(_ line: String, cutoff: Date) -> RawEntry? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty,
          let data = trimmed.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }

    // Timestamp check
    if let tsString = obj["timestamp"] as? String,
       let ts = parseISO8601(tsString), ts < cutoff {
        return nil
    }

    guard let message = obj["message"] as? [String: Any],
          let usage   = message["usage"]   as? [String: Any]
    else { return nil }

    let input  = usage["input_tokens"]  as? Int ?? 0
    let output = usage["output_tokens"] as? Int ?? 0
    guard input > 0 || output > 0 else { return nil }

    let model         = (message["model"] as? String) ?? (obj["model"] as? String) ?? "unknown"
    let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
    let cacheRead     = usage["cache_read_input_tokens"]     as? Int ?? 0

    return RawEntry(
        model: model,
        inputTokens: input,
        outputTokens: output,
        cacheCreationTokens: cacheCreation,
        cacheReadTokens: cacheRead
    )
}

private func aggregate(entries: [RawEntry], hours: Int) -> UsageSnapshot {
    var modelMap: [String: ModelSnapshot] = [:]

    for e in entries {
        if modelMap[e.model] == nil {
            modelMap[e.model] = ModelSnapshot(
                model: e.model, totalTokens: 0,
                inputTokens: 0, outputTokens: 0, messageCount: 0
            )
        }
        modelMap[e.model]!.inputTokens  += e.inputTokens
        modelMap[e.model]!.outputTokens += e.outputTokens
        modelMap[e.model]!.totalTokens  += e.totalTokens
        modelMap[e.model]!.messageCount += 1
    }

    let byModel       = modelMap.values.sorted { $0.totalTokens > $1.totalTokens }
    let totalTokens   = entries.reduce(0) { $0 + $1.totalTokens }
    let inputTokens   = entries.reduce(0) { $0 + $1.inputTokens }
    let outputTokens  = entries.reduce(0) { $0 + $1.outputTokens }

    return UsageSnapshot(
        buckets:             [],
        totalTokens:         totalTokens,
        inputTokens:         inputTokens,
        outputTokens:        outputTokens,
        messageCount:        entries.count,
        byModel:             Array(byModel),
        windowHours:         hours,
        lastUpdated:         Date(),
        monthlyTokens:       0,
        monthlyMessages:     0
    )
}

