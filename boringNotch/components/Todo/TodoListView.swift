//
//  TodoListView.swift
//  boringNotch
//

import SwiftUI

struct TodoListView: View {
    @ObservedObject private var todo = TodoManager.shared
    @State private var newTitle = ""
    @State private var newDetail = ""
    @State private var newTag = ""
    @State private var newProject = ""
    @State private var showAddDetail = false
    @State private var showProjectPicker = false
    @State private var showCompleted = false

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 210)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 12)

            rightPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left panel

    @ViewBuilder
    private var leftPanel: some View {
        if let active = todo.activeTask {
            trackingView(active)
        } else {
            addView
        }
    }

    private var addView: some View {
        VStack(spacing: 7) {
            // Title
            TextField("New task…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { commitAdd() }

            // Tag picker (primary — always visible)
            tagPickerRow

            // Project picker (optional — shown after tag is set or on demand)
            if !newTag.isEmpty || showProjectPicker {
                projectPickerRow
            }

            // Optional detail
            if showAddDetail {
                TextField("Description (optional)", text: $newDetail)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { commitAdd() }
            } else {
                Button(action: { withAnimation(.smooth) { showAddDetail = true } }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8))
                        Text("Add description")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.white.opacity(0.25))
                }
                .buttonStyle(.plain)
            }

            Button(action: { commitAdd() }) {
                Label("Add Task", systemImage: "plus.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.06)
                        : Color.blue.opacity(0.2))
                    .foregroundStyle(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.25)
                        : Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Tag picker

    private var tagPickerRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("#")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.blue.opacity(0.7))
                    .frame(width: 10)

                TextField("tag…", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .onSubmit { commitAdd() }

                if !newTag.isEmpty {
                    Button(action: { newTag = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.blue.opacity(newTag.isEmpty ? 0.1 : 0.3), lineWidth: 1)
            )

            // Existing tag suggestions
            if !todo.tags.isEmpty {
                let suggestions = todo.tags.filter {
                    newTag.isEmpty || $0.localizedCaseInsensitiveContains(newTag)
                }.prefix(4)
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(suggestions), id: \.self) { tag in
                                Button(action: { newTag = tag }) {
                                    Text("#\(tag)")
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(newTag == tag
                                            ? Color.blue.opacity(0.25)
                                            : Color.white.opacity(0.07))
                                        .foregroundStyle(newTag == tag
                                            ? Color.blue
                                            : Color.white.opacity(0.5))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Project picker

    private var projectPickerRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 10)

                TextField("project…", text: $newProject)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .onSubmit { commitAdd() }

                if !newProject.isEmpty {
                    Button(action: { newProject = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                } else if !showProjectPicker {
                    Text("optional")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.white.opacity(newProject.isEmpty ? 0.07 : 0.2), lineWidth: 1)
            )

            // Existing project suggestions
            if !todo.parentProjects.isEmpty {
                let suggestions = todo.parentProjects.filter {
                    newProject.isEmpty || $0.localizedCaseInsensitiveContains(newProject)
                }.prefix(4)
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(suggestions), id: \.self) { proj in
                                Button(action: { newProject = proj }) {
                                    Text(proj)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(newProject == proj
                                            ? Color.white.opacity(0.15)
                                            : Color.white.opacity(0.07))
                                        .foregroundStyle(newProject == proj
                                            ? Color.white.opacity(0.8)
                                            : Color.white.opacity(0.4))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tracking view

    private func trackingView(_ task: TodoItem) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 2) {
                Text(task.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                if let tag = task.tag {
                    Text("#\(tag)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.blue.opacity(0.7))
                } else if let detail = task.detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(TodoManager.format(todo.elapsed))
                .font(.system(size: 32, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.15), value: todo.elapsed)

            HStack(spacing: 6) {
                Button(action: { todo.cancelTracking() }) {
                    Text("Cancel")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation { todo.stopAndSave() } }) {
                    Text("Pause")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation { todo.stopAndComplete() } }) {
                    Text("Done")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Right panel (task list)

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 1) {
                    if todo.pendingItems.isEmpty && !showCompleted {
                        Text("All done!")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(todo.pendingItems) { item in
                            TaskRow(item: item)
                        }

                        if showCompleted {
                            if !todo.completedItems.isEmpty {
                                HStack {
                                    Text("Completed")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                        .textCase(.uppercase)
                                    Spacer()
                                    Button(action: { withAnimation { todo.clearCompleted() } }) {
                                        Text("Clear")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.red.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.top, 6)
                                .padding(.bottom, 2)

                                ForEach(todo.completedItems) { item in
                                    TaskRow(item: item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            Divider().opacity(0.12)
            HStack(spacing: 0) {
                if todo.completedItems.count > 0 {
                    Button(action: { withAnimation(.smooth) { showCompleted.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8))
                            Text(showCompleted
                                 ? "Hide completed"
                                 : "\(todo.completedItems.count) completed")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: { ExpandedDashboardWindow.shared.toggle() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func commitAdd() {
        todo.add(
            title: newTitle,
            detail: showAddDetail ? newDetail : nil,
            tag: newTag.isEmpty ? nil : newTag,
            project: newProject.isEmpty ? nil : newProject
        )
        newTitle = ""
        newDetail = ""
        newTag = ""
        newProject = ""
        showAddDetail = false
        showProjectPicker = false
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @ObservedObject private var todo = TodoManager.shared
    let item: TodoItem
    @State private var isHovering = false

    var isActive: Bool { todo.activeTaskId == item.id }

    var body: some View {
        HStack(spacing: 7) {
            // Checkbox
            Button(action: {
                if !item.isCompleted {
                    withAnimation(.smooth(duration: 0.2)) { todo.stopAndComplete() }
                }
            }) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isActive ? Color.green.opacity(0.8) :
                            item.isCompleted ? Color.white.opacity(0.2) :
                            Color.white.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 15, height: 15)
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    } else if isActive {
                        Circle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(item.isCompleted)

            // Title + metadata
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(item.isCompleted
                        ? Color.white.opacity(0.3)
                        : isActive ? .white : Color.white.opacity(0.85))
                    .strikethrough(item.isCompleted, color: .white.opacity(0.25))
                    .lineLimit(1)

                // Tag + project hint below title
                HStack(spacing: 4) {
                    if let tag = item.tag {
                        Text("#\(tag)")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.blue.opacity(0.65))
                    }
                    if let proj = item.project {
                        if item.tag != nil {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                        Text(proj)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.35))
                    } else if item.tag == nil, let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Duration + resume
            if let duration = item.formattedDuration, !item.isCompleted {
                HStack(spacing: 4) {
                    Text(duration)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.3))
                    if todo.activeTaskId == nil && isHovering {
                        Button(action: { todo.startTracking(item) }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.green)
                                .frame(width: 16, height: 16)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
            } else if let duration = item.formattedDuration, item.isCompleted {
                Text(duration)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
            } else if !item.isCompleted && todo.activeTaskId == nil && isHovering {
                Button(action: { todo.startTracking(item) }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                        .frame(width: 20, height: 20)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }

            // Delete on hover
            if isHovering && todo.activeTaskId != item.id {
                Button(action: { withAnimation { todo.delete(item) } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(width: 14, height: 14)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            isActive ? Color.green.opacity(0.06) :
            isHovering ? Color.white.opacity(0.04) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
