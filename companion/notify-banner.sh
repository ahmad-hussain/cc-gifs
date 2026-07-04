#!/bin/sh
# Optional native macOS banner for the Clawd companion. Wired only by
# `install.sh --with-banner`, mapping:
#   Stop         -> notify-banner.sh done          (Claude finished a turn)
#   Notification -> notify-banner.sh needs-input   (Claude is waiting on you)
#
# Uses terminal-notifier (which shows the Clawd icon) when it's installed, and
# falls back to osascript (a plain banner with the Script Editor icon) otherwise.
# Visual only — no sound, so it never doubles a chime; pair with --with-sound or
# your own audio hook if you want a ding too. Never fails the calling hook.
DIR="$(cd "$(dirname "$0")" && pwd)"
TITLE="Claude Code"

case "$1" in
  done)        MSG="All done ✅" ;;
  needs-input) MSG="Needs your input 👋" ;;
  *)           exit 0 ;;
esac

# Icon: a local companion/banner-icon.png (your own) overrides the generated
# default (generated/clawd-icon.png). Only used by terminal-notifier.
ICON=""
for c in "$DIR/banner-icon.png" "$DIR/../generated/clawd-icon.png"; do
  [ -f "$c" ] && { ICON="$c"; break; }
done

if command -v terminal-notifier >/dev/null 2>&1; then
  if [ -n "$ICON" ]; then
    terminal-notifier -title "$TITLE" -message "$MSG" -contentImage "$ICON" >/dev/null 2>&1 &
  else
    terminal-notifier -title "$TITLE" -message "$MSG" >/dev/null 2>&1 &
  fi
else
  osascript -e "display notification \"$MSG\" with title \"$TITLE\"" >/dev/null 2>&1 &
fi
exit 0
