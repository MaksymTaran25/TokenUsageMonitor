# Contributing to Token Usage Monitor

Thanks for your interest in contributing. This is a personal open-source project — contributions are welcome but please read this guide first.

## Before you start

- Check [open issues](https://github.com/MaksymTaran25/TokenUsageMonitor/issues) to avoid duplicate work
- For significant changes, open an issue first to discuss the approach
- This project uses undocumented Anthropic APIs that may change — keep that in mind when adding features that depend on them

## Development setup

**Requirements:**
- macOS 14.0 (Sonoma) or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code CLI installed and signed in: `npm install -g @anthropic-ai/claude-code && claude login`
- A Claude Pro, Max, or Team subscription

**Getting started:**

```bash
git clone https://github.com/MaksymTaran25/TokenUsageMonitor.git
cd TokenUsageMonitor
./generate.sh   # generates TokenUsageMonitor.xcodeproj and opens Xcode
```

Press `Cmd+R` in Xcode to build and run.

> **Note:** When you first open the project, Xcode will prompt for a Development Team. Set it to your own Apple Developer account in **Signing & Capabilities**, or use a personal team for local builds.

## Project structure

```
Shared/                          # Code shared between app and widget
  UsageData.swift                # All data models + shared utilities

TokenUsageMonitor/               # Main app
  TokenUsageMonitorApp.swift     # App entry point
  MenuBarView.swift              # Menu bar popover UI
  DataManager.swift              # State management and refresh logic
  UsageAPI.swift                 # Anthropic OAuth usage endpoint
  UsageParser.swift              # Local JSONL log parser
  OAuthManager.swift             # Keychain credential loading
  SettingsManager.swift          # User preferences persistence

TokenUsageMonitorWidgetExtension/
  TokenUsageMonitorWidget.swift  # Widget timeline provider
  WidgetViews.swift              # Small / medium / large widget UI

TokenUsageMonitorTests/
  UsageDataTests.swift           # Unit tests for shared models
```

## Running tests

```bash
xcodebuild test \
  -scheme TokenUsageMonitor \
  -destination 'platform=macOS' \
  -only-testing:TokenUsageMonitorTests \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Or press `Cmd+U` in Xcode.

## Code style

- Follow existing Swift conventions in the codebase
- Keep files focused — don't add unrelated changes to a PR
- No third-party dependencies — this project intentionally uses only Apple frameworks
- Add unit tests for any new logic in `Shared/` or the parsing layer

## Submitting a PR

1. Fork the repo and create a branch from `main`
2. Make your changes with clear, focused commits
3. Run tests and make sure they pass
4. Open a pull request with a clear description of what changed and why

## License

By contributing, you agree that your contributions will be licensed under the same [Source-Available License](LICENSE) as this project.
