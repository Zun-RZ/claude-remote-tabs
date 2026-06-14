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
