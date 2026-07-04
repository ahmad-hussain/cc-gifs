#!/bin/sh
# Claude Code PreToolUse hook → once Claude resumes work after a mid-turn block
# (a question / permission the user answered), flip this session's mascot from
# "your turn" back to working. Fast-path: only spawns Python if some session is
# actually waiting, so it's nearly free on the common (nothing-waiting) case.
# Never fails the calling hook.
DIR="$(cd "$(dirname "$0")" && pwd)"
SESS="${TMPDIR:-/tmp}/clawd-companion/sessions"
grep -lq '"waiting"' "$SESS"/*.json 2>/dev/null || exit 0
PY="$DIR/.venv/bin/python3"
[ -x "$PY" ] || exit 0
"$PY" "$DIR/clawd_companion.py" resume 2>/dev/null || true
exit 0
