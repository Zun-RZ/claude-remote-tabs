#!/bin/sh
# Unix/mac keystroke bridge for remote-tabs (started by bin/open-remote-tab).
# Watches an inbox file and injects each new completed line into the tmux session
# via `tmux send-keys`, so built-in commands like /clear (impossible for the model
# or hooks) can be triggered by appending a line to the inbox.
#
# Usage: bridge.sh <tmux-session> <inbox-file>
# Mirrors the Windows pty_host.py: /-commands and !-bash get an ESC first (to close
# any AskUserQuestion/permission/trust modal so the key lands at the command prompt);
# plain prompts are injected as-is. Exits when the tmux session is gone.
SESSION="${1:?usage: bridge.sh <session> <inbox>}"
INBOX="${2:?usage: bridge.sh <session> <inbox>}"
STATE="${INBOX}.offset"
ESC_SETTLE="${ESC_SETTLE:-0.4}"

touch "$INBOX"
# Treat pre-existing inbox content as already processed (no replay on restart).
[ -f "$STATE" ] || wc -l < "$INBOX" | tr -d ' ' > "$STATE"

inject_new() {
  total=$(wc -l < "$INBOX" | tr -d ' ')   # newline-terminated (completed) lines only
  seen=$(cat "$STATE" 2>/dev/null || echo 0)
  [ "$total" -le "$seen" ] && return 0
  tail -n +"$((seen + 1))" "$INBOX" | while IFS= read -r line; do
    case "$line" in
      /* | !*)
        tmux send-keys -t "$SESSION" Escape 2>/dev/null
        sleep "$ESC_SETTLE"
        ;;
    esac
    # -l: type literally (don't interpret "Enter"/"C-c" as key names)
    tmux send-keys -t "$SESSION" -l -- "$line" 2>/dev/null
    tmux send-keys -t "$SESSION" Enter 2>/dev/null
  done
  echo "$total" > "$STATE"
}

# Run while the target session lives. inotifywait (with timeout) when available so
# we still re-check has-session periodically; otherwise poll.
while tmux has-session -t "$SESSION" 2>/dev/null; do
  inject_new
  if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -qq -t 5 -e modify -e close_write "$INBOX" 2>/dev/null || true
  else
    sleep 1
  fi
done
