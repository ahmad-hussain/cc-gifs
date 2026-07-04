#!/bin/sh
# Claude Code Notification hook → mark this session "waiting on input" (hop + red !)
# in the Clawd tray. The hook's JSON (with session_id) arrives on stdin.
# Never fails the calling hook.
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$DIR/.venv/bin/python3"
[ -x "$PY" ] || exit 0
"$PY" "$DIR/clawd_companion.py" notify 2>/dev/null || true
exit 0
