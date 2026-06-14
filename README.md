# claude-remote-tabs

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin that opens background **Remote Control** sessions for the current project — by voice or text, with no stolen window focus — so you can drive them from the Claude mobile app / claude.ai/code.

Just tell your agent "open a new session" and it starts a new, independent session in the background (a minimized terminal on Windows, or a detached `tmux` session on Linux/WSL) with remote control enabled. It shows up in your mobile/web session list, ready to drive from your phone.

## Note: these sessions are not saved locally

A remote-control session opened this way is **not** persisted to local storage — the conversation lives only on claude.ai/code (web), and the local file is an empty stub (so `claude --resume` won't reopen the transcript).

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI (`claude` on your `PATH`)
- **Windows:** PowerShell 5.1 or 7+, plus Git Bash (bundled with Git for Windows — the plugin's entry point runs through the Bash tool)
- **Linux / WSL / macOS:** `tmux`

## Install

```
/plugin marketplace add Zun-RZ/claude-remote-tabs
/plugin install remote-tabs@remote-tabs
```

That's it — no per-project setup, no files copied into your repo.

## Usage

Just ask your agent, in any project:

> open a new session

(or "open a new remote tab", "open a session I can drive from my phone", …)

Claude picks the `open-remote-tab` skill automatically and starts a new background remote-control session. Each invocation starts a **new, independent** session, so multiple can run side by side for the same project.

- **Windows:** a **minimized** PowerShell window (visible in the taskbar so you can close it manually).
- **Linux / WSL / macOS:** a **detached `tmux`** session named `claude-remote-<project>-<sec>-<pid>`.

The shell exits by itself when `claude` ends.

## Optional: no permission prompts (recommended once per project)

By default, the first `open-remote-tab` call in a project triggers a one-time permission prompt. To run without prompts (useful when driving from mobile), ask your agent once — ideally from the desktop:

> set up remote tabs for this project

That runs the `setup-remote-tabs` skill, which merges `Bash(open-remote-tab*)` into the project's `.claude/settings.json` allow-list and sets `permissions.defaultMode` to `auto` (only if not already set). It's idempotent and never overrides existing values.

## Skills

| Skill | Purpose |
|---|---|
| `open-remote-tab` | Start one background remote-control session for the current project |
| `setup-remote-tabs` | One-time opt-in: wire `.claude/settings.json` so sessions run without prompts |

## How it works

`bin/open-remote-tab` is a single POSIX entry point exposed on the Bash tool's `PATH`. It detects the OS via `uname`:

- **Windows** (Git Bash) → hands off to `scripts/open-remote-tab.ps1`, which launches the minimized PowerShell window running `claude --remote-control`.
- **Linux / macOS** → creates the detached `tmux` session running the same.

## License

MIT — see [LICENSE](LICENSE).
