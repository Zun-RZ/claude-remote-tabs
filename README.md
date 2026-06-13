# claude-remote-tabs

Open background [Claude Code](https://docs.claude.com/en/docs/claude-code) **Remote Control** sessions for any project — one command, no stolen window focus — so you can drive them from the Claude mobile app / claude.ai/code.

Each call starts a new, independent session that runs **locally** (a minimized terminal on Windows, or a detached `tmux` session on Linux/WSL) and toggles remote control, so it shows up in your mobile/web session list while still being saved on your machine.

## Why the slash command, not the start flag

`claude --remote-control` (the start flag) does **not** persist the session to local storage: you can't `--resume`/`--teleport` it, the local file is an empty stub, and the conversation lives only on claude.ai/code.

These scripts instead start a normal local session and pass `/remote-control` as the **initial prompt**, which toggles remote control *inside* a locally-saved session — so the session is both remotely controllable **and** reopenable locally.

> Suspected Claude Code bug: the docs say both entry points behave the same; in practice the start flag doesn't persist the transcript locally.

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
