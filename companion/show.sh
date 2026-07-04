#!/bin/sh
# Claude Code UserPromptSubmit hook → mark this session "working" in the Clawd tray.
# The hook's JSON (with session_id) arrives on stdin and is passed through to the
# companion. Never fails the calling hook.
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$DIR/.venv/bin/python3"
[ -x "$PY" ] || exit 0
"$PY" "$DIR/clawd_companion.py" show 2>/dev/null || true
exit 0
