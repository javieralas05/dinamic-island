#!/bin/bash
# Dynamic Island – Claude Code Stop hook
python3 -c "
import socket
msg = b'{"agent":"claude-code","event":"stop","description":"Session ended"}'
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