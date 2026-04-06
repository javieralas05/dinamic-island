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