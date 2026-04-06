//
//  AIAgentModel.swift
//  boringNotch
//

import Foundation

extension Notification.Name {
    static let agentNeedsAttention = Notification.Name("agentNeedsAttention")
}

enum AgentStatus {
    case idle
    case running
    case waiting  // waiting for user approval
}

struct AgentEvent: Identifiable {
    let id: UUID = UUID()
    let agent: String
    let eventType: String
    let tool: String?
    let description: String
    let timestamp: Date = Date()
    var requiresApproval: Bool
    var callbackId: String?
}

/// JSON payload sent by Claude Code hook scripts over the Unix socket
struct AgentHookPayload: Codable {
    let agent: String
    let event: String
    let tool: String?
    let description: String?
    let requiresApproval: Bool?
    let callbackId: String?

    enum CodingKeys: String, CodingKey {
        case agent
        case event
        case tool
        case description
        case requiresApproval = "requires_approval"
        case callbackId = "callback_id"
    }
}
