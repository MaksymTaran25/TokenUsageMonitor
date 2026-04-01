// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.
//
// Loads Claude Code OAuth credentials from the macOS Keychain or the
// fallback credentials file at ~/.claude/.credentials.json.
//
// DISCLAIMER: This uses credentials stored by Claude Code for the purpose
// of reading the user's own usage data. No credentials are transmitted
// to any third party. The token is used solely to call Anthropic's own
// usage endpoint on behalf of the authenticated user.

import Foundation
import OSLog

struct OAuthCredentials {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        // Give a 60-second buffer before actual expiry
        return Date() >= expiresAt.addingTimeInterval(-Constants.OAuth.expiryBufferSeconds)
    }
}

enum CredentialError: Error, LocalizedError {
    case notFound
    case malformed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude Code credentials not found.\nPlease sign in by running the Claude app and completing login."
        case .malformed:
            return "Could not read Claude Code credentials.\nTry signing out and back in from the Claude app."
        }
    }
}

final class OAuthManager {
    static let shared = OAuthManager()
    private init() {}

    private let keychainService  = "Claude Code-credentials"
    private let credentialsFile  = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.credentials.json")

    // MARK: - Public

    func loadCredentials() throws -> OAuthCredentials {
        if let creds = loadFromKeychain() {
            Logger.oauth.debug("Loaded credentials from keychain (expired: \(creds.isExpired))")
            return creds
        }
        if let creds = loadFromFile() {
            Logger.oauth.warning("Keychain empty — fell back to credentials file")
            return creds
        }
        Logger.oauth.error("No credentials found in keychain or file")
        throw CredentialError.notFound
    }

    // MARK: - Keychain

    private func loadFromKeychain() -> OAuthCredentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", keychainService,
            "-w"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let raw = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : parseJSON(raw)
    }

    // MARK: - File fallback

    private func loadFromFile() -> OAuthCredentials? {
        guard let raw = try? String(contentsOf: credentialsFile, encoding: .utf8) else { return nil }
        return parseJSON(raw)
    }

    // MARK: - JSON parsing

    private func parseJSON(_ json: String) -> OAuthCredentials? {
        guard let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Shape: {"claudeAiOauth": {"accessToken": "...", ...}}
        // or flat: {"accessToken": "..."}
        let oauth = obj["claudeAiOauth"] as? [String: Any] ?? obj

        guard let accessToken = oauth["accessToken"] as? String,
              !accessToken.isEmpty
        else { return nil }

        let refreshToken = oauth["refreshToken"] as? String

        var expiresAt: Date? = nil
        if let ms = oauth["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: ms / 1000)
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
}
