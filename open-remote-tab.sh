#!/bin/sh
# Start a Remote Control session for this project in a detached tmux session
# (the Linux/WSL counterpart of open-remote-tab.ps1). Fully background:
# no window, no focus change; tmux provides the TTY claude needs.
# Each call starts a NEW, independent tmux session so multiple remote
# sessions can run side by side for the same project.
#
# NOTE (2026-06-14): a `--remote-control` session is NOT saved locally — the
# conversation lives only on claude.ai/code (web); the local .jsonl is an empty stub.
root="$(pwd)"
base="claude-remote$(echo "$root" | tr '/.' '--')"
name="$base-$(date +%s%N)"
claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"

tmux new-session -d -s "$name" -c "$root" "$claude_bin --remote-control"
echo "remote session started (tmux: $name)"
