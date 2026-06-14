# claude-remote-tabs

Open background [Claude Code](https://docs.claude.com/en/docs/claude-code) **Remote Control** sessions for any project — one command, no stolen window focus — so you can drive them from the Claude mobile app / claude.ai/code.

Each call starts a new, independent session in the background (a minimized terminal on Windows, or a detached `tmux` session on Linux/WSL) with remote control enabled, so it shows up in your mobile/web session list and you can drive it from the Claude mobile app.

## Note: these sessions are not saved locally

A remote-control session opened this way is **not** persisted to local storage — the conversation lives only on claude.ai/code (web), and the local file is an empty stub (so `claude --resume` won't reopen the transcript). This holds regardless of the terminal host (a plain console or Windows Terminal).

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI (`claude` on your `PATH`)
- **Windows:** PowerShell 5.1 or 7+
- **Linux / WSL:** `tmux`, plus `python3` (used by the installer)

## Install (per project)

First clone this repo somewhere stable, e.g. `~/.claude/claude-remote-tabs`:

```sh
git clone https://github.com/Zun-RZ/claude-remote-tabs ~/.claude/claude-remote-tabs
```

Then, from the **target project root** you want to enable remote tabs in, run the installer with the path to your clone:

**Windows**
```powershell
& $HOME\.claude\claude-remote-tabs\setup-claude-tabs.ps1
```

**Linux / WSL**
```sh
sh ~/.claude/claude-remote-tabs/setup-claude-tabs.sh
```

The installer is idempotent and:

- copies `open-remote-tab.{ps1,sh}` into the project's `.claude/`
- merges allow-rules + `defaultMode: auto` into `.claude/settings.json`
- appends a short "Remote sessions" section to the project's `CLAUDE.md` (only if missing)

## Usage

From the project root — or just ask your agent ("open a new session"), since the installer wired the `CLAUDE.md` instruction and the allow-rule:

**Windows**
```powershell
& .\.claude\open-remote-tab.ps1
```

**Linux / WSL**
```sh
.claude/open-remote-tab.sh
```

Each invocation starts a new background session. On Windows it opens a **minimized** terminal (visible in the taskbar so you can close it manually); on Linux/WSL it creates a **detached `tmux`** session named `claude-remote-<project>-<timestamp>`. The shell exits by itself when `claude` ends.

## Files

| File | Purpose |
|---|---|
| `open-remote-tab.ps1` / `.sh` | Start one background remote-control session (Windows / Linux-WSL) |
| `setup-claude-tabs.ps1` / `.sh` | Per-project installer (copies the open script, wires `settings.json` + `CLAUDE.md`) |
| `remote-tab-claude-section.md` | Template the Windows installer appends to a project's `CLAUDE.md` |

## License

MIT — see [LICENSE](LICENSE).
