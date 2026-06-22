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

- Easiest from inside the session (e.g. driven from the phone): run
  **`bridge-send /clear`** — or the short alias **`bg.s /clear`** (easier to type
  on mobile). It appends the line to the inbox so the bridge types it into the
  TUI — the model can't run `/clear` itself, but this makes the bridge inject it.
  Also `bg.s /compact`, `bg.s !git status`, `bg.s "a plain prompt"`.
- Under the hood the inbox path is printed on start (`inbox: …`) and exported as
  `CLAUDE_BRIDGE_INBOX`; `bridge-send` just appends to it (equivalent to
  `echo /clear >> "$CLAUDE_BRIDGE_INBOX"`). Any external writer (SSH, synced file)
  works too.
- `/`- and `!`-prefixed lines get an ESC first to dismiss any open modal
  (turn-end AskUserQuestion, permission, folder-trust) so the key lands at the
  command prompt; plain prompts are injected as-is.
- **Windows needs pywinpty.** If it's missing, the session still starts but
  without injection (a note is printed). Enable it once with
  `scripts/setup-bridge.ps1` (creates a managed venv; no system Python changes),
  or set `REMOTE_TABS_PYTHON` to any python that has pywinpty.
