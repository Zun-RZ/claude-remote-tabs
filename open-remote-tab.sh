#!/bin/sh
# Start a Remote Control session for this project in a detached tmux session
# (the Linux/WSL counterpart of open-remote-tab.ps1). Fully background:
# no window, no focus change; tmux provides the TTY claude needs.
# Each call starts a NEW, independent tmux session so multiple remote
# sessions can run side by side for the same project.
#
# NOTE (2026-06-14): we pass `/remote-control` as the initial prompt instead of the
# `--remote-control` start flag. The start flag does NOT persist the session locally
# (can't --resume/--teleport; the local file is an empty stub and the conversation
# lives only on claude.ai/code). Passing the slash command starts a normal local
# session and toggles remote control inside it, so the session IS saved locally and
# reopenable. (Suspected Claude Code bug: the docs say both entry points behave the
# same; in practice the start flag doesn't persist.)
root="$(pwd)"
base="claude-remote$(echo "$root" | tr '/.' '--')"
name="$base-$(date +%s%N)"
claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"

tmux new-session -d -s "$name" -c "$root" "$claude_bin '/remote-control'"
echo "remote session started (tmux: $name)"
