## 📱 Remote sessions (background, for mobile control)

- "Open a new session" / "open a new tab" → run `& {CLAUDE_DIR}\open-remote-tab.ps1` (each call starts a new, independent remote-control session)
- Install in another project: from the target project root, run
  `& {SETUP_DIR}\setup-claude-tabs.ps1` (idempotent)
- ⚠️ A session opened this way is NOT saved locally — the conversation lives only
  on claude.ai/code (web).
