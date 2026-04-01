// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI
import AppKit

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Preset

    enum Preset: String, CaseIterable {
        case `default` = "Default"
        case ocean     = "Ocean"
        case neon      = "Neon"
        case mono      = "Mono"
        case custom    = "Custom"
    }

    @Published var preset: Preset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: "theme_preset") }
    }

    // MARK: - Custom colors

    @Published var customNormal: Color   { didSet { save(customNormal,   key: "theme_custom_normal") } }
    @Published var customWarning: Color  { didSet { save(customWarning,  key: "theme_custom_warning") } }
    @Published var customCritical: Color { didSet { save(customCritical, key: "theme_custom_critical") } }

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.string(forKey: "theme_preset") ?? "Default"
        preset        = Preset(rawValue: saved) ?? .default
        customNormal   = ThemeManager.load(key: "theme_custom_normal")   ?? .teal
        customWarning  = ThemeManager.load(key: "theme_custom_warning")  ?? .orange
        customCritical = ThemeManager.load(key: "theme_custom_critical") ?? .red
    }

    // MARK: - Resolved colors

    var normalGradient: [Color] {
        switch preset {
        case .default: return [.teal,               .cyan]
        case .ocean:   return [.blue,               .indigo]
        case .neon:    return [.green,              .mint]
        case .mono:    return [Color(white: 0.55),  Color(white: 0.72)]
        case .custom:  return [customNormal,        customNormal.opacity(0.65)]
        }
    }

    var warningGradient: [Color] {
        switch preset {
        case .default: return [.orange,             .yellow]
        case .ocean:   return [.purple,             .pink]
        case .neon:    return [.yellow,             .orange]
        case .mono:    return [Color(white: 0.55),  Color(white: 0.72)]
        case .custom:  return [customWarning,       customWarning.opacity(0.65)]
        }
    }

    var criticalGradient: [Color] {
        switch preset {
        case .default: return [.red,                .pink]
        case .ocean:   return [.red,                .orange]
        case .neon:    return [.orange,             .red]
        case .mono:    return [Color(white: 0.55),  Color(white: 0.72)]
        case .custom:  return [customCritical,      customCritical.opacity(0.65)]
        }
    }

    var normalGlow: Color {
        switch preset {
        case .default: return .cyan
        case .ocean:   return .blue
        case .neon:    return .green
        case .mono:    return Color(white: 0.6)
        case .custom:  return customNormal
        }
    }

    var warningGlow: Color {
        switch preset {
        case .default: return .orange
        case .ocean:   return .purple
        case .neon:    return .yellow
        case .mono:    return Color(white: 0.5)
        case .custom:  return customWarning
        }
    }

    var criticalGlow: Color {
        switch preset {
        case .default: return .red
        case .ocean:   return .red
        case .neon:    return .orange
        case .mono:    return Color(white: 0.4)
        case .custom:  return customCritical
        }
    }

    // MARK: - Persistence

    private static func load(key: String) -> Color? {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [Double], arr.count == 4 else { return nil }
        return Color(.sRGB, red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
    }

    private func save(_ color: Color, key: String) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        UserDefaults.standard.set(
            [Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent)],
            forKey: key
        )
    }
}
