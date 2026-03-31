<p align="center">
  <img src="https://developer.apple.com/assets/elements/icons/swiftui/swiftui-96x96_2x.png" width="80" />
</p>

<h1 align="center">Token Usage Monitor</h1>

<p align="center">
  Monitor your Claude AI usage limits directly from your macOS menu bar and desktop widgets.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" />
  <img src="https://img.shields.io/badge/WidgetKit-supported-green" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" />
</p>

> **Disclaimer:** This is an unofficial, community-built tool. It is **not affiliated with, endorsed by, or supported by Anthropic**. It uses undocumented APIs that may change or break at any time. Use at your own risk.

---

## Features

- **Menu bar app** — live percentage display of your current rate limit usage
- **Three widget sizes** — small, medium, and large desktop widgets via WidgetKit
- **Weekly widget** — dedicated widget for seven-day usage tracking
- **Token breakdown** — per-model stats (input/output tokens) parsed from local Claude logs
- **Monthly summary** — cumulative token and message counts
- **Configurable refresh** — choose polling interval (1–15 min) to balance freshness vs. rate limiting
- **Customizable layout** — show/hide and reorder sections in the menu bar popover
- **Glassmorphism UI** — gradient progress bars with glow effects on translucent material cards

## Prerequisites

- **macOS 14.0** or later
- **Claude Code** installed and authenticated (`claude` command, then `/login`)
- A **Claude Pro, Max, or Team** subscription (free plans do not expose usage data)

## Build from Source

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
git clone https://github.com/MaksymTaran25/TokenUsageMonitor.git
cd TokenUsageMonitor
./generate.sh
```

This generates the Xcode project and opens it. Press **Cmd + R** to build and run.

> On first launch, macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

After launching, add widgets by right-clicking the desktop → **Edit Widgets** → search "Token Usage Monitor".

## Project Structure

```
TokenUsageMonitor/
├── Shared/
│   └── UsageData.swift              # Models shared between app and widgets
├── TokenUsageMonitor/
│   ├── TokenUsageMonitorApp.swift   # App entry point (MenuBarExtra)
│   ├── MenuBarView.swift            # Menu bar popover UI
│   ├── DataManager.swift            # State management and refresh logic
│   ├── UsageAPI.swift               # Anthropic OAuth usage endpoint
│   ├── UsageParser.swift            # Local JSONL log parser
│   ├── OAuthManager.swift           # Keychain credential loading
│   └── SettingsManager.swift        # User preferences persistence
├── TokenUsageMonitorWidgetExtension/
│   ├── TokenUsageMonitorWidget.swift # Widget definitions and timeline
│   └── WidgetViews.swift            # Small/medium/large widget UIs
├── project.yml                       # XcodeGen project config
└── generate.sh                       # Project generation script
```

## How It Works

1. **OAuth credentials** are read from the macOS Keychain (stored by Claude Code) — no manual token setup required
2. **Rate limit data** is fetched from Anthropic's internal OAuth usage endpoint
3. **Token breakdown** is parsed from Claude Code's local JSONL conversation logs in `~/.claude/projects/`
4. Data is shared with widgets via an App Group container

## License

[MIT](LICENSE)
