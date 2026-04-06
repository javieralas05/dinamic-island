//
//  HookInstaller.swift
//  boringNotch
//

import Foundation

/// Auto-installs Claude Code hooks so the notch receives agent events without manual configuration.
class HookInstaller {
    static let shared = HookInstaller()

    private let hooksDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("boringNotch/hooks")
    }()

    private let claudeSettingsURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }()

    private var installedKey = "claudeHooksInstalled_v2"

    private var isInstalled: Bool {
        get { UserDefaults.standard.bool(forKey: installedKey) }
        set { UserDefaults.standard.set(newValue, forKey: installedKey) }
    }

    private init() {}

    func installIfNeeded() {
        guard !isInstalled else { return }
        install()
    }

    func install() {
        do {
            try writeHookScripts()
            try updateClaudeSettings()
            isInstalled = true
            print("[HookInstaller] Claude Code hooks installed successfully")
        } catch {
            print("[HookInstaller] Installation failed: \(error)")
        }
    }

    // MARK: - Scripts

    private func writeHookScripts() throws {
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        let scripts: [(String, String)] = [
            ("pre_tool_use.sh", preToolUseScript),
            ("notification.sh", notificationScript),
            ("stop.sh", stopScript)
        ]

        for (name, content) in scripts {
            let url = hooksDir.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: url.path
            )
        }
    }

    // MARK: - Claude Settings

    private func updateClaudeSettings() throws {
        var settings: [String: Any] = [:]

        if let data = try? Data(contentsOf: claudeSettingsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let preToolPath = hooksDir.appendingPathComponent("pre_tool_use.sh").path
        let notifPath = hooksDir.appendingPathComponent("notification.sh").path
        let stopPath = hooksDir.appendingPathComponent("stop.sh").path

        hooks["PreToolUse"] = [[
            "matcher": ".*",
            "hooks": [["type": "command", "command": preToolPath]]
        ]]
        hooks["Notification"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": notifPath]]
        ]]
        hooks["Stop"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": stopPath]]
        ]]

        settings["hooks"] = hooks

        let output = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )

        // Create ~/.claude/ if needed
        let claudeDir = claudeSettingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try output.write(to: claudeSettingsURL)
    }

    // MARK: - Script Templates

    private var preToolUseScript: String {
        """
        #!/bin/bash
        # Dynamic Island – Claude Code PreToolUse hook
        # Sends approval request to the notch app and waits for the user's decision.
        PAYLOAD=$(cat)
        CALLBACK_ID="claude-$$-$(date +%s)"
        RESPONSE_FILE="/tmp/${CALLBACK_ID}.json"

        # Extract tool name and a short description from the payload
        TOOL=$(echo "$PAYLOAD" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name','tool'))" 2>/dev/null || echo "tool")
        ARGS=$(echo "$PAYLOAD" | python3 -c "
        import json, sys
        d = json.load(sys.stdin).get('tool_input', {})
        v = list(d.values())
        print(str(v[0])[:80] if v else '')
        " 2>/dev/null || echo "")

        # Build JSON message and send to the app over Unix socket
        # Use Python for socket I/O to guarantee SHUT_WR after sending
        # (macOS nc does not support -N and may not close the write-end)
        python3 -c "
        import json, socket, sys
        msg = json.dumps({
            'agent': 'claude-code',
            'event': 'pre_tool_use',
            'requires_approval': True,
            'callback_id': sys.argv[1],
            'tool': sys.argv[2],
            'description': sys.argv[3]
        }).encode()
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect('/tmp/dinamic-island.sock')
            s.sendall(msg)
            s.shutdown(socket.SHUT_WR)
            s.close()
        except Exception:
            pass
        " "$CALLBACK_ID" "$TOOL" "$ARGS" 2>/dev/null || true

        # Poll for response (max 60 seconds)
        for i in $(seq 60); do
            sleep 1
            if [ -f "$RESPONSE_FILE" ]; then
                DECISION=$(python3 -c "import json,sys; print(json.load(open('$RESPONSE_FILE'))['decision'])" 2>/dev/null || echo "allow")
                rm -f "$RESPONSE_FILE"
                if [ "$DECISION" = "block" ]; then
                    echo "Blocked by Dynamic Island" >&2
                    exit 2
                fi
                exit 0
            fi
        done

        # Timeout – allow by default so Claude Code is never permanently blocked
        exit 0
        """
    }

    private var notificationScript: String {
        """
        #!/bin/bash
        # Dynamic Island – Claude Code Notification hook
        PAYLOAD=$(cat)
        python3 -c "
        import json, socket, sys
        d = json.loads(sys.argv[1])
        msg = json.dumps({
            'agent': 'claude-code',
            'event': 'notification',
            'description': d.get('message', '')
        }).encode()
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect('/tmp/dinamic-island.sock')
            s.sendall(msg)
            s.shutdown(socket.SHUT_WR)
            s.close()
        except Exception:
            pass
        " "$PAYLOAD" 2>/dev/null || true
        exit 0
        """
    }

    private var stopScript: String {
        """
        #!/bin/bash
        # Dynamic Island – Claude Code Stop hook
        python3 -c "
        import socket
        msg = b'{\"agent\":\"claude-code\",\"event\":\"stop\",\"description\":\"Session ended\"}'
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect('/tmp/dinamic-island.sock')
            s.sendall(msg)
            s.shutdown(socket.SHUT_WR)
            s.close()
        except Exception:
            pass
        " 2>/dev/null || true
        exit 0
        """
    }
}
