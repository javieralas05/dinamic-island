//
//  TimeTrackerManager.swift
//  boringNotch
//

import Foundation
import Combine

struct TrackedSession: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval
    let label: String
    var detail: String?

    var formattedDuration: String { TimeTrackerManager.format(duration) }

    var formattedStart: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: startedAt)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startedAt)
    }
}

class TimeTrackerManager: ObservableObject {
    static let shared = TimeTrackerManager()

    enum TimerState { case idle, running, stopped }

    @Published var state: TimerState = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var currentLabel: String = ""
    @Published var currentDetail: String = ""
    @Published var sessions: [TrackedSession] = []

    private var startDate: Date?
    private var cancellable: AnyCancellable?
    private let sessionsKey = "timeTracker.sessions"

    private init() { loadSessions() }

    // MARK: - Controls

    func start() {
        guard state == .idle, !currentLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        startDate = Date()
        elapsed = 0
        state = .running
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
    }

    func stop() {
        guard state == .running else { return }
        cancellable?.cancel()
        cancellable = nil
        state = .stopped
    }

    func save() {
        guard state == .stopped, let start = startDate else { return }
        let trimmedDetail = currentDetail.trimmingCharacters(in: .whitespaces)
        let session = TrackedSession(
            id: UUID(),
            startedAt: start,
            duration: elapsed,
            label: currentLabel.trimmingCharacters(in: .whitespaces),
            detail: trimmedDetail.isEmpty ? nil : trimmedDetail
        )
        sessions.insert(session, at: 0)
        if sessions.count > 100 { sessions = Array(sessions.prefix(100)) }
        persistSessions()
        reset()
    }

    func discard() { reset() }

    func delete(_ session: TrackedSession) {
        sessions.removeAll { $0.id == session.id }
        persistSessions()
    }

    // MARK: - Computed

    var todayTotal: TimeInterval {
        sessions.filter(\.isToday).reduce(0) { $0 + $1.duration }
    }

    // MARK: - Helpers

    private func reset() {
        elapsed = 0
        startDate = nil
        currentLabel = ""
        currentDetail = ""
        state = .idle
    }

    static func format(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Persistence

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let saved = try? JSONDecoder().decode([TrackedSession].self, from: data)
        else { return }
        sessions = saved
    }
}
