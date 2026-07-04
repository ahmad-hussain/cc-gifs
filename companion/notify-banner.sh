#!/bin/sh
# Optional native macOS banner for the Clawd companion. Wired only by
# `install.sh --with-banner`, mapping:
#   Stop         -> notify-banner.sh done          (Claude finished a turn)
#   Notification -> notify-banner.sh needs-input   (Claude is waiting on you)
#
# "needs-input" fires only on a genuine mid-turn block (a question / permission
# prompt), NOT on Claude Code's idle "waiting for your input" nudge. The robust,
# message-agnostic signal is the tray's per-session state file: it exists only
# while a turn is in progress (created on UserPromptSubmit, removed on Stop), so
# an idle prompt (turn already ended) has no file. (If the tray isn't installed,
# it falls back to matching the idle message text.) The title includes the
# session name. Uses terminal-notifier (Clawd icon) when installed, else
# osascript. Visual only — no sound. Never fails the calling hook.
DIR="$(cd "$(dirname "$0")" && pwd)"
EVENT="$1"
case "$EVENT" in
  done)        MSG="All done ✅" ;;
  needs-input) MSG="Needs your input 👋" ;;
  *)           exit 0 ;;
esac

NAME=""; SKIP="0"
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
  if [ -n "$INPUT" ]; then
    RES="$(printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json, sys, os, glob, tempfile
event = sys.argv[1] if len(sys.argv) > 1 else ""
try: d = json.load(sys.stdin)
except Exception: d = {}
sid = str(d.get("session_id") or "")
msg = str(d.get("message") or "")

name = ""
if sid:
    mt = -1
    for p in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
        try:
            o = json.load(open(p)); m = os.path.getmtime(p)
        except Exception:
            continue
        if o.get("sessionId") == sid and m > mt:
            mt = m; name = (o.get("name") or "").strip()

skip = False
if event == "needs-input":
    sess_dir = os.path.join(tempfile.gettempdir(), "clawd-companion", "sessions")
    if os.path.isdir(sess_dir):
        safe = "".join(c for c in sid if c.isalnum() or c in "-_")[:80] or "default"
        skip = not os.path.exists(os.path.join(sess_dir, safe + ".json"))  # no active turn -> idle
    else:
        skip = "waiting for your input" in msg.lower()  # no tray -> best-effort message check
print(("1" if skip else "0") + "|" + name)
' "$EVENT" 2>/dev/null)"
    SKIP="${RES%%|*}"
    NAME="${RES#*|}"
  fi
fi
[ "$SKIP" = "1" ] && exit 0

TITLE="Claude Code"
[ -n "$NAME" ] && TITLE="Claude Code · $NAME"

ICON=""
for c in "$DIR/banner-icon.png" "$DIR/../generated/clawd-icon.png"; do
  [ -f "$c" ] && { ICON="$c"; break; }
done

if command -v terminal-notifier >/dev/null 2>&1; then
  set -- -title "$TITLE" -message "$MSG"
  [ -n "$ICON" ] && set -- "$@" -contentImage "$ICON"
  terminal-notifier "$@" >/dev/null 2>&1 &
else
  osascript -e "display notification \"$MSG\" with title \"$TITLE\"" >/dev/null 2>&1 &
fi
exit 0
