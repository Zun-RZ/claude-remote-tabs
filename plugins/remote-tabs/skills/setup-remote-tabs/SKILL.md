---
name: setup-remote-tabs
description: Use when the user wants to set up, configure, or enable remote tabs
  for the current project so background sessions run without permission prompts
  from their phone. One-time opt-in that wires the project's settings.json.
---

# Set up remote tabs for this project

This is a one-time, opt-in setup. It lets `open-remote-tab` run without a
permission prompt (important when driving from mobile). Edit the file directly —
no python/jq/node needed.

1. Read `.claude/settings.json` in the current project. If it does not exist,
   start from `{}` (create the `.claude/` directory if needed).
2. Ensure `permissions.allow` includes `Bash(open-remote-tab*)`. Append it only
   if absent (do not duplicate).
3. Set `permissions.defaultMode` to `auto` **only if the key is not already
   present** — never override an existing value.
4. Write the file back as valid JSON, preserving all other keys and formatting
   as closely as possible.
5. Confirm to the user exactly what changed (or that nothing needed changing).

After setup, remind the user: on the **first** `open-remote-tab` call before
setup they'd see one permission prompt; once this is done, mobile/remote
invocations run without prompts.
