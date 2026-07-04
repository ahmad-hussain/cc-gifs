#!/bin/sh
# Setup for the Clawd working companion (macOS). Three optional cues you can mix:
#   • Visual tray   — a Clawd mascot per session (working / needs-you / done)
#   • Sound cues    — a chime on done / needs-input
#   • Banner notifs — a native macOS banner on done / needs-input
#
# Interactive (preview, then choose which cues):
#   ./companion/install.sh
#
# Non-interactive (scripts / agents):
#   ./companion/install.sh --install-hooks [--no-tray] [--with-sound] [--with-banner]
#   ./companion/install.sh --print         [--no-tray] [--with-sound] [--with-banner]
#
# --install-hooks merges the chosen hooks into ~/.claude/settings.json (timestamped
# backup; idempotent; preserves existing hooks). --print just shows the JSON.
# Default component is the tray; add --no-tray to omit it. Safe to re-run. Restart
# Claude Code afterward so the hooks load.
set -e

COMPANION="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$COMPANION/.." && pwd)"
VENV="$COMPANION/.venv"
PY_SYS="/usr/bin/python3"

if [ "$(uname)" != "Darwin" ]; then
  echo "!!  The companion is macOS-only (AppKit / afplay / osascript)."
  echo "    You can still generate GIFs on any OS: pip install -r requirements.txt && python3 generate_clawd_gifs.py"
  exit 0
fi

# --- parse args -----------------------------------------------------------
MODE=""; TRAY="1"; SOUND="0"; BANNER="0"
for a in "$@"; do
  case "$a" in
    --install-hooks) MODE="merge" ;;
    --print)         MODE="print" ;;
    --no-tray)       TRAY="0" ;;
    --with-sound)    SOUND="1" ;;
    --with-banner)   BANNER="1" ;;
    -h|--help)
      echo "usage: install.sh [--install-hooks|--print] [--no-tray] [--with-sound] [--with-banner]"
      echo "       (no mode flag + a terminal = interactive: preview, then choose cues)"
      exit 0 ;;
    *) echo "!!  unknown option: $a"; exit 2 ;;
  esac
done

INTERACTIVE="0"
if [ -z "$MODE" ] && [ -t 0 ]; then INTERACTIVE="1"; MODE="merge"; fi
[ -z "$MODE" ] && MODE="print"

echo "==> Clawd companion install ($REPO)"

ensure_build() {
  if [ ! -x "$VENV/bin/python3" ]; then
    echo "==> creating venv ($PY_SYS) at $VENV"
    "$PY_SYS" -m venv "$VENV"
  fi
  echo "==> installing deps (Pillow + pyobjc-framework-Cocoa)"
  "$VENV/bin/python3" -m pip install --quiet --upgrade pip
  "$VENV/bin/python3" -m pip install --quiet -r "$REPO/requirements.txt" -r "$COMPANION/requirements.txt"
  echo "==> generating GIFs + banner icon"
  "$VENV/bin/python3" "$REPO/generate_clawd_gifs.py" >/dev/null
}

preview() {
  echo "==> preview (watch the bottom-right corner / listen / watch for a banner):"
  echo "    • tray mascot (~5s)"
  "$VENV/bin/python3" "$COMPANION/clawd_companion.py" preview >/dev/null 2>&1 || true
  "$VENV/bin/python3" -c "import time; time.sleep(5)"
  "$VENV/bin/python3" - <<'PY' 2>/dev/null || true
import os, glob, tempfile, signal
sd = os.path.join(tempfile.gettempdir(), "clawd-companion")
for f in glob.glob(os.path.join(sd, "sessions", "*.json")):
    try: os.remove(f)
    except Exception: pass
try: os.kill(int(open(os.path.join(sd, "daemon.lock")).read().strip()), signal.SIGTERM)
except Exception: pass
PY
  echo "    • sound cues (done, then needs-input)"
  "$COMPANION/chime.sh" done; "$VENV/bin/python3" -c "import time; time.sleep(1.1)"; "$COMPANION/chime.sh" needs-input
  echo "    • banner notification"
  "$COMPANION/notify-banner.sh" done
}

# Build when the tray or banner is in play (they need the venv / GIFs / icon);
# the interactive path builds up front so previews work.
if [ "$TRAY" = "1" ] || [ "$BANNER" = "1" ] || [ "$INTERACTIVE" = "1" ]; then
  ensure_build
fi

if [ "$INTERACTIVE" = "1" ]; then
  echo ""
  echo "Three optional cues — mix any (Claude working / needs your input / done):"
  echo "  1) Visual tray    2) Sound cues    3) Banner notifications"
  echo ""
  printf "Preview them now? [y/N] "; read a || a=""
  case "$a" in [Yy]*) preview ;; esac
  echo ""
  printf "Enable the visual tray (Clawd mascot per session)? [Y/n] "; read a || a=""
  case "$a" in [Nn]*) TRAY="0" ;; *) TRAY="1" ;; esac
  printf "Enable sound cues (chime on done / needs-input)? [y/N] "; read a || a=""
  case "$a" in [Yy]*) SOUND="1" ;; *) SOUND="0" ;; esac
  printf "Enable banner notifications (native macOS banner)? [y/N] "; read a || a=""
  case "$a" in [Yy]*) BANNER="1" ;; *) BANNER="0" ;; esac
  if [ "$BANNER" = "1" ] && ! command -v terminal-notifier >/dev/null 2>&1; then
    printf "Install terminal-notifier for a custom icon on banners (uses Homebrew)? [y/N] "; read a || a=""
    case "$a" in [Yy]*) brew install terminal-notifier || echo "   (install failed — banners will use the default icon)" ;; esac
  fi
fi

# --- wire (or print) the hooks for the chosen components ------------------
"$PY_SYS" - "$COMPANION" "$MODE" "$TRAY" "$SOUND" "$BANNER" <<'PYEOF'
import json, os, shutil, sys, time

companion, mode = sys.argv[1], sys.argv[2]
tray, sound, banner = sys.argv[3] == "1", sys.argv[4] == "1", sys.argv[5] == "1"

EVENTS = []
if tray:
    EVENTS += [("UserPromptSubmit", "show.sh", ""), ("PreToolUse", "resume.sh", ""),
               ("PostToolUse", "resume.sh", ""), ("Notification", "notify.sh", ""),
               ("Stop", "hide.sh", "")]
if sound:
    EVENTS += [("Notification", "chime.sh", "needs-input"), ("Stop", "chime.sh", "done")]
if banner:
    EVENTS += [("Notification", "notify-banner.sh", "needs-input"), ("Stop", "notify-banner.sh", "done")]

def command(script, arg):
    return os.path.join(companion, script) + (" " + arg if arg else "")

def entry(script, arg):
    return {"type": "command", "command": command(script, arg), "async": True}

if not EVENTS:
    print("!!  No components selected — nothing to wire.")
    sys.exit(0)

if mode == "print":
    hooks = {}
    for ev, s, arg in EVENTS:
        hooks.setdefault(ev, []).append({"hooks": [entry(s, arg)]})
    print("\n==> Add these to the \"hooks\" object in ~/.claude/settings.json")
    print("    (merge into any existing hooks; then restart Claude Code):\n")
    print(json.dumps({"hooks": hooks}, indent=2))
else:
    path = os.path.expanduser("~/.claude/settings.json")
    settings = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                settings = json.load(f)
        except Exception as e:
            print(f"!!  could not parse {path}: {e}\n    Fix it, or use --print and merge by hand.")
            sys.exit(1)
        bak = f"{path}.bak-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.copy2(path, bak)
        print(f"==> backed up settings to {bak}")
    hooks = settings.setdefault("hooks", {})
    added = 0
    for ev, s, arg in EVENTS:
        cmd = command(s, arg)
        arr = hooks.setdefault(ev, [])
        if not any(cmd in json.dumps(m) for m in arr):
            arr.append({"hooks": [entry(s, arg)]})
            added += 1
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
    chosen = ", ".join(c for c, on in (("tray", tray), ("sound", sound), ("banner", banner)) if on)
    print(f"==> merged {added} new hook(s) into {path} ({len(EVENTS) - added} already present)")
    print(f"==> components enabled: {chosen}")
PYEOF

echo ""
echo "Done. Restart Claude Code so the hooks load."
