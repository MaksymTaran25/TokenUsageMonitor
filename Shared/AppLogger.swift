// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import OSLog

/// Centralised OSLog loggers. View output in Console.app → filter by "TokenUsageMonitor".
extension Logger {
    private static let subsystem = "com.tokenusagemonitor.app"

    /// OAuth credential loading and token lifecycle.
    static let oauth   = Logger(subsystem: subsystem, category: "OAuth")

    /// Anthropic API requests and responses.
    static let api     = Logger(subsystem: subsystem, category: "API")

    /// DataManager refresh cycles and persistence.
    static let data    = Logger(subsystem: subsystem, category: "Data")

    /// Local JSONL log parsing.
    static let parser  = Logger(subsystem: subsystem, category: "Parser")

    /// Widget timeline generation.
    static let widget  = Logger(subsystem: subsystem, category: "Widget")
}
