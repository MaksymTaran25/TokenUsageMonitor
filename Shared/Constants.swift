// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import Foundation

enum Constants {

    /// Time window sizes in hours.
    enum Time {
        static let hours24:     Int = 24
        static let hours7d:     Int = 168
        static let hours30d:    Int = 720
        static let validWindows: [Int] = [hours24, hours7d, hours30d]
    }

    /// Auto-refresh timing.
    enum Refresh {
        static let defaultIntervalSeconds: Int      = 300   // 5 minutes
        static let maxBackoffSeconds:      TimeInterval = 1800  // 30 minutes
    }

    /// OAuth credential handling.
    enum OAuth {
        /// Treat token as expired this many seconds before its actual expiry.
        static let expiryBufferSeconds: TimeInterval = 60
    }

    /// Network request settings.
    enum API {
        static let timeoutSeconds: TimeInterval = 15
    }

    /// Local JSONL log parsing.
    enum Parser {
        /// When scanning files by mtime, skip files older than the window by this buffer.
        static let fileModificationBufferSeconds: TimeInterval = 3600  // 1 hour
    }
}
