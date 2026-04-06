//
//  AIAgentManager.swift
//  boringNotch
//

import Foundation
import SwiftUI

class AIAgentManager: ObservableObject {
    static let shared = AIAgentManager()

    @Published var activeAgents: [String: AgentStatus] = [:]
    @Published var pendingApproval: AgentEvent? = nil
    @Published var recentEvents: [AgentEvent] = []

    private let socketPath = "/tmp/dinamic-island.sock"
    private var serverFD: Int32 = -1
    private var isRunning = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Remove any stale socket file
        unlink(socketPath)

        // Create Unix domain socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            print("[AIAgentManager] Failed to create socket")
            return
        }

        // Build address
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { ptr in
            socketPath.utf8CString.withUnsafeBytes { src in
                ptr.copyMemory(from: src)
            }
        }

        let bindResult = withUnsafePointer(to: addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFD, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("[AIAgentManager] Failed to bind socket")
            close(serverFD)
            return
        }

        listen(serverFD, 5)

        let fd = serverFD
        Task.detached(priority: .background) { [weak self] in
            while true {
                let clientFD = accept(fd, nil, nil)
                guard clientFD >= 0 else { break }
                Task { await self?.handleClient(fd: clientFD) }
            }
        }
    }

    func stop() {
        isRunning = false
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        unlink(socketPath)
    }

    // MARK: - Client Handling

    private func handleClient(fd: Int32) async {
        defer { close(fd) }

        var data = Data()
        let bufSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }

        while true {
            let n = read(fd, buffer, bufSize)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }

        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(AgentHookPayload.self, from: data)
        else { return }

        let event = AgentEvent(
            agent: payload.agent,
            eventType: payload.event,
            tool: payload.tool,
            description: payload.description ?? payload.event,
            requiresApproval: payload.requiresApproval ?? false,
            callbackId: payload.callbackId
        )

        await MainActor.run {
            self.processEvent(event)
        }
    }

    @MainActor
    private func processEvent(_ event: AgentEvent) {
        switch event.eventType {
        case "stop":
            activeAgents[event.agent] = .idle
        case "pre_tool_use" where event.requiresApproval:
            activeAgents[event.agent] = .waiting
            pendingApproval = event
            openNotchOnAgentsTab()
        default:
            activeAgents[event.agent] = .running
            openNotchOnAgentsTab()
        }

        recentEvents.insert(event, at: 0)
        if recentEvents.count > 20 {
            recentEvents.removeLast()
        }
    }

    @MainActor
    private func openNotchOnAgentsTab() {
        BoringViewCoordinator.shared.currentView = .agents
        NotificationCenter.default.post(name: .agentNeedsAttention, object: nil)
    }

    // MARK: - Approval

    @MainActor
    func approve() {
        guard let event = pendingApproval else { return }
        if let callbackId = event.callbackId {
            writeCallback(callbackId: callbackId, decision: "allow")
        }
        activeAgents[event.agent] = .running
        pendingApproval = nil
    }

    @MainActor
    func deny() {
        guard let event = pendingApproval else { return }
        if let callbackId = event.callbackId {
            writeCallback(callbackId: callbackId, decision: "block")
        }
        activeAgents[event.agent] = .idle
        pendingApproval = nil
    }

    private func writeCallback(callbackId: String, decision: String) {
        let response = ["decision": decision]
        guard let data = try? JSONEncoder().encode(response) else { return }
        FileManager.default.createFile(atPath: "/tmp/\(callbackId).json", contents: data)
    }
}
