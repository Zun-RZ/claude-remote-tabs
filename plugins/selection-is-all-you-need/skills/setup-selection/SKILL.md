---
name: setup-selection
description: Use to reduce the one-time mobile permission prompt for AskUserQuestion and check push-notification settings. Run once, ideally from desktop.
---

# setup-selection

When `selection-is-all-you-need` calls AskUserQuestion at the end of every
turn, mobile may show a one-time "Allow AskUserQuestion?" prompt per session.
It doesn't block anything, but it's annoying. This skill tries to reduce it.

## What it does (best-effort)

1. Read the user's `~/.claude/settings.json` (create it if missing) and add
   `"AskUserQuestion"` to `permissions.allow` if it isn't already there.
   Preserve existing values; the operation is idempotent.
2. Check push-notification settings and advise: `agentPushNotifEnabled`
   (recommended `true`) and `preferredNotifChannel`.

## Limitation (always tell the user)

AskUserQuestion is officially not permission-gated (Claude Code Tools
reference: `Permission Required: No`), so the allow entry may not remove the
prompt. In that case, tell the user clearly that the once-per-session
confirmation is platform (mobile app) behavior that a plugin cannot remove,
then stop.
