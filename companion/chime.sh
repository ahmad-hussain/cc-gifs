#!/bin/sh
# Optional audio cue for the Clawd companion (macOS). Plays a system sound for a
# companion event. Wired only when you run `install.sh --with-sound`, mapping:
#   Stop         -> chime.sh done          (Claude finished a turn)
#   Notification -> chime.sh needs-input   (Claude is waiting on you)
#
# Change the two sounds below to taste — any file in /System/Library/Sounds/
# works (e.g. Glass, Funk, Hero, Submarine, Purr, Ping, Blow, Bottle, Tink).
DONE_SOUND="Glass"
NEEDS_INPUT_SOUND="Funk"

case "$1" in
  done)        SND="$DONE_SOUND" ;;
  needs-input) SND="$NEEDS_INPUT_SOUND" ;;
  *)           exit 0 ;;
esac

# Play detached so the hook returns instantly; never fail the calling hook.
afplay "/System/Library/Sounds/${SND}.aiff" >/dev/null 2>&1 &
exit 0
