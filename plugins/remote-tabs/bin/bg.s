#!/bin/sh
# Short, easy-to-type alias for bridge-send (handy on mobile): bg.s /clear
# Resolves bridge-send next to itself first (works even when bin/ isn't on PATH,
# e.g. run by full path), then falls back to PATH. One implementation, no drift.
dir=$(dirname -- "$0")
if [ -f "$dir/bridge-send" ]; then
  exec "$dir/bridge-send" "$@"
fi
exec bridge-send "$@"
