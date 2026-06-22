---
name: open-remote-tab
description: Use when the user asks to open a new background session, a new
  remote tab, or a session they can drive from their phone / the Claude mobile
  app. Starts a detached remote-control Claude Code session for the current
  project.
---

# Open a remote-control session

Run `open-remote-tab` via the Bash tool. It starts a new background
remote-control Claude Code session for the current project and prints
`remote session started …`.

- Report that line back to the user verbatim.
- If it errors (e.g. `tmux is required`, launcher not found), surface the error
  verbatim and stop — do not retry blindly.
- Each invocation starts a NEW, independent session, so multiple remote sessions
  can run side by side for the same project.

The new session appears in your claude.ai/code (web) and Claude mobile app
session list. Note: a remote-control session is NOT saved locally — the
conversation lives only on the web.

## Keystroke bridge (built-in commands like /clear)

The session is started inside a keystroke-injectable container (tmux on Unix; a
pywinpty ConPTY host on Windows), with an **inbox** file watched in the
background. Appending a line to the inbox **types it into the real TUI**, so
built-in commands the model/hooks can't trigger — `/clear`, `/compact`,
`/model`, plus `!`bash and plain prompts — actually fire.

- The inbox path is printed on start (`inbox: …`) and exported into the session
  as `CLAUDE_BRIDGE_INBOX`. From inside the session (e.g. driven from the phone),
  the model can trigger a built-in by running bash:
  `echo /clear >> "$CLAUDE_BRIDGE_INBOX"` — the model can't run `/clear` itself,
  but writing to the inbox makes the bridge inject it.
- `/`- and `!`-prefixed lines get an ESC first to dismiss any open modal
  (turn-end AskUserQuestion, permission, folder-trust) so the key lands at the
  command prompt; plain prompts are injected as-is.
- **Windows needs pywinpty.** If it's missing, the session still starts but
  without injection (a note is printed). Enable it once with
  `scripts/setup-bridge.ps1` (creates a managed venv; no system Python changes),
  or set `REMOTE_TABS_PYTHON` to any python that has pywinpty.
