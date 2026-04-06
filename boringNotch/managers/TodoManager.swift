//
//  TodoManager.swift
//  boringNotch
//

import Foundation
import Combine

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var tag: String?        // primary label (formerly "project")
    var project: String?    // optional parent project (new)
    var isCompleted: Bool
    let createdAt: Date
    var trackedDuration: TimeInterval?
    var startedAt: Date?
    var completedAt: Date?

    var formattedDuration: String? {
        guard let d = trackedDuration else { return nil }
        return TodoManager.format(d)
    }

    var isTracked: Bool { trackedDuration != nil }
    var isToday: Bool { Calendar.current.isDateInToday(createdAt) }
    var completedToday: Bool {
        guard let d = completedAt else { return false }
        return Calendar.current.isDateInToday(d)
    }

    // MARK: - Codable (with v1→v2 migration)

    enum CodingKeys: String, CodingKey {
        case id, title, detail, tag, project, isCompleted, createdAt
        case trackedDuration, startedAt, completedAt
    }

    init(id: UUID, title: String, detail: String? = nil, tag: String? = nil,
         project: String? = nil, isCompleted: Bool, createdAt: Date,
         trackedDuration: TimeInterval? = nil, startedAt: Date? = nil, completedAt: Date? = nil) {
        self.id = id; self.title = title; self.detail = detail
        self.tag = tag; self.project = project
        self.isCompleted = isCompleted; self.createdAt = createdAt
        self.trackedDuration = trackedDuration
        self.startedAt = startedAt; self.completedAt = completedAt
    }

    // Old format had a single "project" key used as a tag.
    // If "tag" key is absent we're reading v1 data: migrate "project" → tag, project = nil.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        detail      = try c.decodeIfPresent(String.self, forKey: .detail)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        createdAt   = try c.decode(Date.self, forKey: .createdAt)
        trackedDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .trackedDuration)
        startedAt   = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        if c.contains(.tag) {
            tag     = try c.decodeIfPresent(String.self, forKey: .tag)
            project = try c.decodeIfPresent(String.self, forKey: .project)
        } else {
            // v1 migration: old "project" field was actually a tag
            tag     = try c.decodeIfPresent(String.self, forKey: .project)
            project = nil
        }
    }
}

class TodoManager: ObservableObject {
    static let shared = TodoManager()

    @Published var items: [TodoItem] = []
    @Published var activeTaskId: UUID? = nil
    @Published var elapsed: TimeInterval = 0

    private var trackingStartDate: Date?
    private var cancellable: AnyCancellable?
    private let storageKey = "todo.items.v2"

    private init() { load() }

    // MARK: - Task actions

    func add(title: String, detail: String? = nil, tag: String? = nil, project: String? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(
            id: UUID(), title: trimmed,
            detail: detail?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            tag: tag?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            project: project?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            isCompleted: false, createdAt: Date()
        )
        items.insert(item, at: 0)
        persist()
    }

    func delete(_ item: TodoItem) {
        if activeTaskId == item.id { cancelTracking() }
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted }
        persist()
    }

    /// Removes a tag from every item that carries it (items themselves are kept).
    func removeTag(_ tag: String) {
        for i in items.indices where items[i].tag == tag {
            items[i].tag = nil
        }
        persist()
    }

    /// Removes a parent project from every item that belongs to it (items themselves are kept).
    func removeProject(_ project: String) {
        for i in items.indices where items[i].project == project {
            items[i].project = nil
        }
        persist()
    }

    // MARK: - Time tracking

    func startTracking(_ item: TodoItem) {
        guard activeTaskId == nil else { return }
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let existing = item.trackedDuration ?? 0
        trackingStartDate = Date().addingTimeInterval(-existing)
        elapsed = existing
        activeTaskId = item.id
        if items[idx].startedAt == nil {
            items[idx].startedAt = Date()
        }
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.trackingStartDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
    }

    func stopAndComplete() {
        guard let id = activeTaskId,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
        stopTimer()
        items[idx].trackedDuration = elapsed
        items[idx].completedAt = Date()
        items[idx].isCompleted = true
        reorder()
        persist()
        activeTaskId = nil
        elapsed = 0
    }

    func stopAndSave() {
        guard let id = activeTaskId,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
        stopTimer()
        items[idx].trackedDuration = elapsed
        reorder()
        persist()
        activeTaskId = nil
        elapsed = 0
    }

    func cancelTracking() {
        guard let id = activeTaskId,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
        stopTimer()
        items[idx].startedAt = nil
        activeTaskId = nil
        elapsed = 0
    }

    var activeTask: TodoItem? {
        guard let id = activeTaskId else { return nil }
        return items.first { $0.id == id }
    }

    // MARK: - Computed

    var pendingItems: [TodoItem]   { items.filter { !$0.isCompleted } }
    var completedItems: [TodoItem] { items.filter { $0.isCompleted } }

    /// Unique tags in insertion order.
    var tags: [String] {
        let all = items.compactMap { $0.tag }
        return Array(NSOrderedSet(array: all)) as? [String] ?? []
    }

    /// Unique parent projects in insertion order.
    var parentProjects: [String] {
        let all = items.compactMap { $0.project }
        return Array(NSOrderedSet(array: all)) as? [String] ?? []
    }

    // MARK: - Analytics

    func todayCompletedItems() -> [TodoItem] {
        items.filter { $0.completedToday }
    }

    func weeklyHours() -> [(date: Date, seconds: TimeInterval)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset -> (Date, TimeInterval) in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            let total = items
                .filter { item in
                    guard let d = item.completedAt else { return false }
                    return cal.isDate(d, inSameDayAs: day)
                }
                .compactMap { $0.trackedDuration }
                .reduce(0, +)
            return (day, total)
        }
    }

    func exportTodayText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let dateStr = formatter.string(from: Date())
        let completed = todayCompletedItems()
        let total = completed.compactMap { $0.trackedDuration }.reduce(0, +)
        var lines = ["Hoy — \(dateStr)", String(repeating: "─", count: 32)]
        for item in completed {
            let dur = item.formattedDuration ?? "--:--"
            var label = ""
            if let t = item.tag { label += "  [#\(t)]" }
            if let p = item.project { label += "  [\(p)]" }
            lines.append("✓ \(item.title.padding(toLength: 28, withPad: " ", startingAt: 0)) \(dur)\(label)")
        }
        lines.append("  Total: \(TodoManager.format(total))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func stopTimer() {
        cancellable?.cancel()
        cancellable = nil
        trackingStartDate = nil
    }

    private func reorder() {
        let pending   = items.filter { !$0.isCompleted }
        let completed = items.filter { $0.isCompleted }
        items = pending + completed
    }

    static func format(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([TodoItem].self, from: data)
        else { return }
        items = saved
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
