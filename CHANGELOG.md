# Changelog

All notable changes to Token Usage Monitor are documented here.

## [Unreleased]

- Unit test suite for UsageParser and data models

---

## [1.2.0] - 2026-04-01

### Fixed
- Widgets now appear in the macOS widget picker when installed via Homebrew or DMG
- Replaced App Group shared container with widget's own sandbox container, eliminating the need for a paid Apple Developer account to provision the App Group

---

## [1.1.0] - 2026-04-01

### Fixed
- Fixed pipe deadlock bug that caused Agent Watchers session detection to hang silently
- Fixed incorrect working directory detection in Agent Watchers (missing `-a` flag in `lsof`)
- Agent Watchers polling now only runs while the panel is open

### Changed
- Click any Agent Watcher session to bring its terminal to the foreground (falls back to Finder)
- Launch at login checkbox layout matches Notifications row

---

## [1.0.0] - 2026-03-31

### Added
- Menu bar app showing live rate limit percentage (Five hours / Seven days buckets)
- Small, Medium, and Large desktop widgets via WidgetKit
- Dedicated Weekly Usage small widget for seven-day tracking
- Token breakdown by model (Opus, Sonnet, Haiku) parsed from local Claude logs in `~/.claude/projects/`
- Monthly summary - 30-day cumulative token and message counts
- Customizable menu bar layout - show/hide and drag-to-reorder sections
- Time window switcher - 24h, 7-day, and 30-day views for token stats
- Rate limit handling - graceful fallback on 429, shows last known data
- Auto-refresh every 5 minutes in the background
- OAuth credentials loaded from macOS Keychain (stored by Claude Code CLI)
- App Group data sharing between main app and widget extension
- Custom gauge app icon
- XcodeGen-based project setup (`generate.sh`, `project.yml`)
- Build and DMG packaging script (`build.sh`)
- Source-Available license

### Changed
- Replaced MIT license with Source-Available license

---

[Unreleased]: https://github.com/MaksymTaran25/TokenUsageMonitor/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/MaksymTaran25/TokenUsageMonitor/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/MaksymTaran25/TokenUsageMonitor/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MaksymTaran25/TokenUsageMonitor/releases/tag/v1.0.0
