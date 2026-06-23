#!/bin/sh
# Short, easy-to-type alias for send-key (handy on mobile): s.k /clear
# Resolves send-key next to itself first (works even when bin/ isn't on PATH,
# e.g. run by full path), then falls back to PATH. One implementation, no drift.
dir=$(dirname -- "$0")
if [ -f "$dir/send-key" ]; then
  exec "$dir/send-key" "$@"
fi
exec send-key "$@"
