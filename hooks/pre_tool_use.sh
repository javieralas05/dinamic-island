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