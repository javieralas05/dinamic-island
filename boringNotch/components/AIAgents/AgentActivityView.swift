//
//  AgentActivityView.swift
//  boringNotch
//

import SwiftUI

struct AgentActivityView: View {
    @ObservedObject var agentManager = AIAgentManager.shared

    var body: some View {
        Group {
            if let pending = agentManager.pendingApproval {
                approvalView(for: pending)
            } else {
                statusView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Status View

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if agentManager.activeAgents.isEmpty && agentManager.recentEvents.isEmpty {
                emptyState
            } else {
                agentStatusList
                if !agentManager.recentEvents.isEmpty {
                    Divider().opacity(0.3)
                    recentEventsList
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No active AI agents")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agentStatusList: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(agentManager.activeAgents).sorted(by: { $0.key < $1.key }), id: \.key) { agent, status in
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 7, height: 7)
                    Text(displayName(for: agent))
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(statusLabel(status))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentEventsList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(agentManager.recentEvents.prefix(3)) { event in
                HStack(spacing: 6) {
                    Image(systemName: icon(for: event.eventType))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(event.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Approval View

    private func approvalView(for event: AgentEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(displayName(for: event.agent))
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("Approval needed")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let tool = event.tool {
                    Text(tool)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                Button(action: { agentManager.deny() }) {
                    Label("Deny", systemImage: "xmark")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.18))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { agentManager.approve() }) {
                    Label("Approve", systemImage: "checkmark")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func statusColor(_ status: AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .running: return .green
        case .waiting: return .orange
        }
    }

    private func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .idle: return "idle"
        case .running: return "running"
        case .waiting: return "waiting"
        }
    }

    private func displayName(for agent: String) -> String {
        switch agent {
        case "claude-code": return "Claude Code"
        default: return agent
        }
    }

    private func icon(for eventType: String) -> String {
        switch eventType {
        case "pre_tool_use": return "wrench.fill"
        case "post_tool_use": return "checkmark.circle.fill"
        case "notification": return "bell.fill"
        case "stop": return "stop.circle.fill"
        default: return "circle.fill"
        }
    }
}
