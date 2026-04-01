// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import SwiftUI

struct AgentWatchersView: View {
    @ObservedObject private var service = AgentWatchersService.shared

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            if service.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
            Text("Agent Watchers")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            if !service.sessions.isEmpty {
                Text("\(service.sessions.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No active Claude sessions")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Session list

    private var sessionList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(service.sessions) { session in
                    SessionRow(session: session)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .shadow(color: .green.opacity(0.6), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.shortName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(session.displayPath)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text("PID \(session.id)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
