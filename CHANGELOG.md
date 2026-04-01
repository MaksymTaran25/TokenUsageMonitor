# Changelog

All notable changes to Token Usage Monitor are documented here.

## [Unreleased]

- Unit test suite for UsageParser and data models

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

[Unreleased]: https://github.com/MaksymTaran25/TokenUsageMonitor/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/MaksymTaran25/TokenUsageMonitor/releases/tag/v1.0.0
