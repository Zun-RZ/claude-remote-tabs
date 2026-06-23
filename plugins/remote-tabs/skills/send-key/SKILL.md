---
name: send-key
description: Use INSIDE a remote-control session when the user's message starts
  with "s.k …" or "send-key …" — inject the rest of the line as a TUI command
  into this session via the keystroke bridge (the model and hooks cannot type it
  themselves). Triggers on e.g. "s.k /compact", "send-key /clear".
---

# Fire a TUI command via the keystroke bridge

The user wants a terminal/TUI command run in **this** session — most importantly a
built-in like `/clear`, `/compact`, `/model`, `/config`. You **cannot** run those
yourself and hooks can't either; the only way is to type them into the real TUI.
This session was started with a keystroke bridge that watches an inbox file and
types each appended line into the TUI, so you trigger the command by writing to it.

## Steps

1. The message starts with the prefix; the command is the rest:
   - `s.k X` or `send-key X` → the command is `X` (e.g. `/clear`, `!git status`)
2. Run it via the Bash tool:
   ```
   send-key <command>
   ```
   `send-key` appends the line to `$CLAUDE_BRIDGE_INBOX`; the bridge then types
   it into the TUI (slash/`!` lines get an ESC first to clear any open modal).
   Report the `queued: …` line back.
3. If `send-key` prints `not in a keystroke-bridge session`, this session wasn't
   started with the bridge — tell the user to open it with `open-remote-tab` and stop.

Do **not** try to emulate `/clear` (or any built-in) yourself — only the injected
keystroke fires it. Just queue the line and let the bridge do the typing.
