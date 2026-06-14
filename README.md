<h1 align="center">claude-remote-tabs</h1>

<p align="center"><strong><em>DO YOU GUYS NOT HAVE PHONES?</em></strong></p>

<p align="center">
  <img src="docs/images/do-you-guys-not-have-phones.png" alt="DO YOU GUYS NOT HAVE PHONES?" width="100%">
</p>

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin that opens — and closes — background **Remote Control** sessions by voice or text, with no stolen window focus, so you can drive them from the Claude mobile app / claude.ai/code. Just tell your agent *"open a new session"* and a fresh, independent session spins up in the background (a minimized terminal on Windows, or a detached `tmux` session on Linux/WSL) and shows up in your mobile/web session list, ready to drive from your phone.

## Install (Claude Code plugin)

Add the marketplace first — on its own line. Don't paste an install line in the same message (it gets swallowed into this one as a bad repo argument and the clone fails).

```
/plugin marketplace add Zun-RZ/claude-remote-coding
```

### Install Two Plugins

Install whichever you want — **one at a time** (each `/plugin` line on its own message).

- **`remote-tabs`** — open/close background remote-control sessions.
  ```
  /plugin install remote-tabs@claude-remote-coding
  ```
- **`selection-is-all-you-need`** — it pushes a notification to your phone at the end of every turn, and it also helps your decisions.
  With explicit stop signals (종료, 그만, stop, exit, etc.), it skips the AskUserQuestion.
  ```
  /plugin install selection-is-all-you-need@claude-remote-coding
  ```

No per-project setup — nothing is copied into your repo.

> Heads up: `selection-is-all-you-need` ships a forced output style, so it
> overrides any custom output style you've selected (your coding instructions
> are preserved via `keep-coding-instructions`). If two forced-style plugins
> are enabled, the first one loaded wins.

## First open a session locally, then go mobile

You can't bootstrap from a cold start on your phone: opening a session needs a Claude Code agent already running to execute the command. So **start your first session on the desktop the normal way** (`claude`), then from that session ask it to *"open a new session"*. From then on every running session — including ones you opened remotely — can spawn more, so you can keep adding tabs straight from the mobile app.

## Usage

Just ask your agent, in any project:

> open a new session

(or *"open a new remote tab"*, *"open a session I can drive from my phone"*, …)

Claude picks the `open-remote-tab` skill automatically and starts a new background remote-control session. Each invocation starts a **new, independent** session, so multiple can run side by side for the same project.

- **Windows:** a **minimized** PowerShell window (visible in the taskbar so you can close it manually).
- **Linux / WSL / macOS:** a **detached `tmux`** session named `claude-remote-<project>-<sec>-<pid>`.

The shell exits by itself when `claude` ends.

### Closing a session

Background sessions pile up. To clear the one you're in, just say:

> close this session

(or *"end this session"*, *"이 세션 종료"*, …)

Claude picks the `close-remote-tab` skill, asks for **one** confirmation (terminating drops the connection and no result comes back — on mobile it shows as a disconnect), and on `종료`/confirm ends the current session. It only ever closes the session you're in, never others.

## Optional: no permission prompts (recommended once per project)

By default, the first `open-remote-tab` call in a project triggers a one-time permission prompt. To run without prompts (useful when driving from mobile), ask your agent once — ideally from the desktop:

> set up remote tabs for this project

That runs the `setup-remote-tabs` skill, which merges `Bash(open-remote-tab*)` into the project's `.claude/settings.json` allow-list and sets `permissions.defaultMode` to `auto` (only if not already set). It's idempotent and never overrides existing values.

## First run in a new folder: trust it

When you open a session in a folder Claude Code hasn't opened before, the new background session pauses on a one-time **"Do you trust the files in this folder?"** prompt. Approve it (from the mobile app / web) before the session can start working.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI (`claude` on your `PATH`)
- **Windows:** PowerShell 5.1 or 7+, plus Git Bash (bundled with Git for Windows — the plugin's entry point runs through the Bash tool)
- **Linux / WSL / macOS:** `tmux`

## Note: these sessions are not saved locally

A remote-control session opened this way is **not** persisted to local storage — the conversation lives only on claude.ai/code (web), and the local file is an empty stub (so `claude --resume` won't reopen the transcript).

## Skills

| Skill | Purpose |
|---|---|
| `open-remote-tab` | Start one background remote-control session for the current project |
| `close-remote-tab` | End the current session (after one confirmation) — keeps zombie sessions from piling up |
| `setup-remote-tabs` | One-time opt-in: wire `.claude/settings.json` so sessions run without prompts |

## How it works

`bin/open-remote-tab` and `bin/close-remote-tab` are single POSIX entry points exposed on the Bash tool's `PATH`. Each detects the OS via `uname`:

- **open — Windows** (Git Bash) → hands off to `scripts/open-remote-tab.ps1`, which launches the minimized PowerShell window running `claude --remote-control`. **Linux / macOS** → creates the detached `tmux` session running the same.
- **close — Windows** → `scripts/close-remote-tab.ps1` walks up the process tree to the current `claude.exe`/`node.exe` and terminates it (the launcher window then closes on its own). **Linux / macOS** → kills the current `tmux` session, or walks up to the current `claude`/`node` process when not in `tmux`.

## License

MIT — see [LICENSE](LICENSE).
