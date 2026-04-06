//
//  TimeTrackerView.swift
//  boringNotch
//

import SwiftUI

struct TimeTrackerView: View {
    @ObservedObject private var tracker = TimeTrackerManager.shared

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 210)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 14)

            historyPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left panel (timer controls)

    @ViewBuilder
    private var leftPanel: some View {
        switch tracker.state {
        case .idle:   idleView
        case .running: runningView
        case .stopped: stoppedView
        }
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            TextField("Activity name…", text: $tracker.currentLabel)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { tracker.start() }

            TextField("Description (optional)", text: $tracker.currentDetail)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { tracker.start() }

            Text("00:00")
                .font(.system(size: 30, weight: .thin, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.2))

            Button(action: { tracker.start() }) {
                Label("Start", systemImage: "play.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(tracker.currentLabel.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.07)
                        : Color.green.opacity(0.2))
                    .foregroundStyle(tracker.currentLabel.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.3)
                        : Color.green)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(tracker.currentLabel.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }

    private var runningView: some View {
        VStack(spacing: 6) {
            Text(tracker.currentLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)

            if !tracker.currentDetail.isEmpty {
                Text(tracker.currentDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text(TimeTrackerManager.format(tracker.elapsed))
                .font(.system(size: 34, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.15), value: tracker.elapsed)

            Button(action: { tracker.stop() }) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }

    private var stoppedView: some View {
        VStack(spacing: 6) {
            Text(tracker.currentLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            if !tracker.currentDetail.isEmpty {
                Text(tracker.currentDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(TimeTrackerManager.format(tracker.elapsed))
                .font(.system(size: 34, weight: .thin, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))

            HStack(spacing: 8) {
                Button(action: { tracker.discard() }) {
                    Text("Discard")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { tracker.save() }) {
                    Text("Save")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.25))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Right panel (history)

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Today summary header
            HStack {
                Text("Today")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if tracker.todayTotal > 0 {
                    Text(TimeTrackerManager.format(tracker.todayTotal))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if tracker.sessions.isEmpty {
                Spacer()
                Text("No sessions yet")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.2))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(tracker.sessions.prefix(8)) { session in
                            sessionRow(session)
                        }
                        if tracker.sessions.count > 8 {
                            Text("+ \(tracker.sessions.count - 8) more")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sessionRow(_ session: TrackedSession) -> some View {
        HStack(spacing: 6) {
            // Color dot — today vs older
            Circle()
                .fill(session.isToday ? Color.blue.opacity(0.7) : Color.white.opacity(0.15))
                .frame(width: 5, height: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let detail = session.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                } else {
                    Text(session.formattedStart)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            Spacer()

            Text(session.formattedDuration)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
