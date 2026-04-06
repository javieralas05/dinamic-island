//
//  ExpandedDashboardView.swift
//  boringNotch
//

import SwiftUI

struct ExpandedDashboardView: View {
    @ObservedObject private var todo = TodoManager.shared
    @State private var selectedTab: DashboardTab = .today

    enum DashboardTab { case today, week }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().opacity(0.12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        if selectedTab == .today {
                            todaySection
                        } else {
                            weekSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }

                Divider().opacity(0.12)

                footer
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 500, height: 480)
        .preferredColorScheme(.dark)
        .onKeyPress(.escape) {
            ExpandedDashboardWindow.shared.close()
            return .handled
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 2) {
                tabButton("Today", tab: .today)
                tabButton("Week", tab: .week)
            }
            .padding(3)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: { ExpandedDashboardWindow.shared.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
        }
    }

    private func tabButton(_ label: String, tab: DashboardTab) -> some View {
        Button(action: { withAnimation(.smooth(duration: 0.2)) { selectedTab = tab } }) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                statCard(
                    value: humanDuration(todayTotalSeconds),
                    label: "Tracked today",
                    color: .green
                )
                statCard(
                    value: "\(todo.todayCompletedItems().count)",
                    label: "Tasks done",
                    color: .blue
                )
                statCard(
                    value: "\(todo.pendingItems.count)",
                    label: "Pending",
                    color: .orange
                )
            }

            if todo.todayCompletedItems().isEmpty {
                Text("No tasks completed today yet.")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 1) {
                    sectionHeader("Completed today")
                    ForEach(todo.todayCompletedItems()) { item in
                        dashboardTaskRow(item)
                    }
                }
            }

            let trackedPending = todo.pendingItems.filter { $0.isTracked }
            if !trackedPending.isEmpty {
                VStack(spacing: 1) {
                    sectionHeader("In progress")
                    ForEach(trackedPending) { item in
                        dashboardTaskRow(item)
                    }
                }
            }
        }
    }

    // MARK: - Week Section

    private var weekSection: some View {
        VStack(spacing: 12) {
            let weekly = todo.weeklyHours()
            let maxSeconds = weekly.map { $0.seconds }.max() ?? 1

            // Bar chart — labels row + bars row + day names row all with fixed heights
            VStack(spacing: 0) {
                sectionHeader("Hours per day")
                    .padding(.bottom, 8)

                // Labels row (fixed height)
                HStack(spacing: 6) {
                    ForEach(Array(weekly.enumerated()), id: \.offset) { _, entry in
                        Text(entry.seconds > 0 ? shortDuration(entry.seconds) : "")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 14)

                // Bars row — fixed 80pt container, bars bottom-aligned with direct height calc
                let chartHeight: CGFloat = 80
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(weekly.enumerated()), id: \.offset) { _, entry in
                        let ratio = maxSeconds > 0 ? CGFloat(entry.seconds) / CGFloat(maxSeconds) : 0
                        let isToday = Calendar.current.isDateInToday(entry.date)
                        let barHeight = Swift.max(3, chartHeight * ratio)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isToday ? Color.green.opacity(0.7) : Color.white.opacity(0.2))
                            .frame(maxWidth: .infinity, maxHeight: barHeight)
                    }
                }
                .frame(height: chartHeight)
                .padding(.top, 4)

                // Day names row (fixed height, fixed gap from bar bottom)
                HStack(spacing: 6) {
                    ForEach(Array(weekly.enumerated()), id: \.offset) { _, entry in
                        let isToday = Calendar.current.isDateInToday(entry.date)
                        let dayFormatter: DateFormatter = {
                            let f = DateFormatter(); f.dateFormat = "EEE"; return f
                        }()
                        Text(dayFormatter.string(from: entry.date).prefix(2).uppercased())
                            .font(.system(size: 8, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 16)
                .padding(.top, 4)
            }

            // Weekly total
            let weeklyTotal = weekly.map { $0.seconds }.reduce(0, +)
            HStack {
                Text("Weekly total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(humanDuration(weeklyTotal))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 4)

            // Breakdown: project groups → tags within each group
            let hasAnyTag = !todo.tags.isEmpty
            if hasAnyTag {
                byTagSection
            }
        }
    }

    // MARK: - Reusable components

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.3))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    // MARK: - By-tag breakdown (hierarchical: project → tags)

    private var byTagSection: some View {
        VStack(spacing: 4) {
            sectionHeader("By project / tag")

            // 1. Items that belong to a parent project, grouped by project
            ForEach(todo.parentProjects, id: \.self) { proj in
                projectGroupView(proj)
            }

            // 2. Items with a tag but no parent project
            let unlinked = todo.items.filter { $0.project == nil && $0.tag != nil }
            let unlinkedTags = orderedTags(from: unlinked)
            if !unlinkedTags.isEmpty {
                if !todo.parentProjects.isEmpty {
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                        Text("no project")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 2)
                }
                ForEach(unlinkedTags, id: \.self) { tag in
                    tagRow(tag: tag, items: unlinked.filter { $0.tag == tag })
                }
            }
        }
    }

    private func projectGroupView(_ project: String) -> some View {
        let projItems = todo.items.filter { $0.project == project }
        let totalSecs = projItems.compactMap { $0.trackedDuration }.reduce(0, +)
        let projTags  = orderedTags(from: projItems)

        return VStack(spacing: 2) {
            // Project header row
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text(project)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer()
                if totalSecs > 0 {
                    Text(humanDuration(totalSecs))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Tag rows within this project (indented)
            ForEach(projTags, id: \.self) { tag in
                tagRow(tag: tag, items: projItems.filter { $0.tag == tag })
                    .padding(.leading, 14)
            }

            // Items in this project with no tag
            let noTagItems = projItems.filter { $0.tag == nil }
            if !noTagItems.isEmpty {
                tagRow(tag: nil, items: noTagItems)
                    .padding(.leading, 14)
            }
        }
    }

    private func tagRow(tag: String?, items: [TodoItem]) -> some View {
        TagRowView(tag: tag, items: items)
    }

    private func orderedTags(from items: [TodoItem]) -> [String] {
        let all = items.compactMap { $0.tag }
        return Array(NSOrderedSet(array: all)) as? [String] ?? []
    }

    private func dashboardTaskRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.isCompleted ? Color.green.opacity(0.6) : Color.orange.opacity(0.7))
                .frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11))
                    .foregroundStyle(item.isCompleted ? Color.white.opacity(0.6) : .white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let tag = item.tag {
                        Text("#\(tag)")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.blue.opacity(0.6))
                    }
                    if let proj = item.project {
                        Text(proj)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
            }
            Spacer()
            if let d = item.trackedDuration {
                Text(humanDuration(d))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(todo.items.count) total tasks")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.25))
            Spacer()
            Button(action: exportToday) {
                Label("Copy Report", systemImage: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var todayTotalSeconds: TimeInterval {
        todo.todayCompletedItems().compactMap { $0.trackedDuration }.reduce(0, +)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: Date())
    }

    /// Human-readable duration: "5m 30s", "1h 20m", "2h"
    private func humanDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0             { return "\(h)h" }
        if m > 0 && s > 0   { return "\(m)m \(s)s" }
        if m > 0             { return "\(m)m" }
        if s > 0             { return "\(s)s" }
        return "0s"
    }

    /// Short label for bar chart tops: "1h 20m", "34m", "<1m"
    private func shortDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h\(m > 0 ? " \(m)m" : "")" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    private func exportToday() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(todo.exportTodayText(), forType: .string)
    }
}

// MARK: - Tag Row (standalone view for hover + delete)

private struct TagRowView: View {
    @ObservedObject private var todo = TodoManager.shared
    let tag: String?
    let items: [TodoItem]
    @State private var isHovering = false

    private var totalSecs: TimeInterval {
        items.compactMap { $0.trackedDuration }.reduce(0, +)
    }
    private var completedCount: Int { items.filter { $0.isCompleted }.count }

    private func humanDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        if s > 0 { return "\(s)s" }
        return "0s"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tag != nil ? Color.blue.opacity(0.5) : Color.white.opacity(0.2))
                .frame(width: 5, height: 5)

            Text(tag.map { "#\($0)" } ?? "–")
                .font(.system(size: 10))
                .foregroundStyle(tag != nil ? Color.blue.opacity(0.8) : Color.white.opacity(0.35))

            Spacer()

            Text("\(completedCount)/\(items.count)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            if totalSecs > 0 {
                Text(humanDuration(totalSecs))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(width: 60, alignment: .trailing)
            }

            // Delete button — only for named tags, shown on hover
            if let tag, isHovering {
                Button(action: { todo.removeTag(tag) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 14, height: 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove tag from all tasks")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovering ? Color.white.opacity(0.05) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
