---
name: send-key
description: Use INSIDE a remote-control session when the user's message IS a TUI
  command for this session to run — a built-in slash command (/clear, /compact,
  /model, /config), a bash-mode line (starting with !), or an explicit "bg.s …"
  or "bridge-send …". The model cannot run /clear and friends itself; this injects
  the command into the real TUI via the keystroke bridge so it actually fires.
  Triggers on short messages that ARE such a command (e.g. "/clear", "bg.s /compact").
---

# Fire a TUI command via the keystroke bridge

The user wants a terminal/TUI command run in **this** session — most importantly a
built-in like `/clear`, `/compact`, `/model`, `/config`. You **cannot** run those
yourself and hooks can't either; the only way is to type them into the real TUI.
This session was started with a keystroke bridge that watches an inbox file and
types each appended line into the TUI, so you trigger the command by writing to it.

## Steps

1. Work out the command line from the user's message:
   - `bg.s X` or `bridge-send X` → the command is `X`
   - otherwise the whole message is the command (e.g. `/clear`, `!git status`)
2. Run it via the Bash tool:
   ```
   bridge-send <command>
   ```
   `bridge-send` appends the line to `$CLAUDE_BRIDGE_INBOX`; the bridge then types
   it into the TUI (slash/`!` lines get an ESC first to clear any open modal).
   Report the `queued: …` line back.
3. If `bridge-send` prints `not in a keystroke-bridge session`, this session wasn't
   started with the bridge — tell the user to open it with `open-remote-tab` and stop.

Do **not** try to emulate `/clear` (or any built-in) yourself — only the injected
keystroke fires it. Just queue the line and let the bridge do the typing.
