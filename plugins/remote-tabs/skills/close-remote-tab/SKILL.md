---
name: close-remote-tab
description: Use when the user asks to close, end, terminate, or quit the
  current session — e.g. "이 세션 종료", "close this session", "세션 끝내",
  "end this session" — OR sends the exact fast-close keyword `#@stop#@` as the
  main content of their input. This includes the keyword arriving as an
  AskUserQuestion answer (a selected option's notes, or the "Other" free-text
  input), not only a plain chat message. Ends the very session the user is
  currently in.
---

# Close the current session

The user wants to end the session they are currently in.

## Fast close (`#@stop#@`)

If the user's input is essentially just the keyword `#@stop#@` — it is the
**main content** of the input (trivial surrounding whitespace, or at most a word
or two, is fine) — then **skip the confirmation** and go straight to terminating
the session (step 2 below). This keyword is a deliberate, unambiguous "kill now"
signal, so do **not** ask `AskUserQuestion` first.

This applies regardless of how the keyword arrives. In particular, when the turn
ended with an `AskUserQuestion` and the user replied through it, the keyword may
come back inside the tool result — as the notes on a selected option, or as the
"Other" free-text input — rather than as a plain chat message. If `#@stop#@` is
the main content of that answer, treat it exactly like a fast-close message and
terminate immediately.

Do **not** fast-close if the keyword merely appears buried inside an otherwise
unrelated message or answer — that is not the main content. For any other
phrasing ("close this session", "이 세션 종료", …), follow the normal
confirm-first flow.

1. **Confirm once, with `AskUserQuestion`.** Make the consequence explicit in the
   question: terminating this session drops the connection and **no result will
   be reported back** (on mobile it shows as a disconnect). Offer two options:
   `Terminate` and `Cancel`.
2. **Terminate the session** (reached either via the fast-close path above, or
   only once the user picks `Terminate` in step 1) — pick the command by OS:
   - **Windows:** run this plugin's `scripts/close-remote-tab.ps1` via the
     **PowerShell tool** (e.g. `& "<this-plugin>/scripts/close-remote-tab.ps1"`).
     Do **not** use the Bash tool on Windows: its Git Bash shell is not reliably
     a descendant of the current `claude.exe`, so the script's parent-process
     walk can't find the session and fails with the "could not locate" error.
     The PowerShell tool runs as a direct child of `claude.exe`, so the walk
     succeeds.
   - **Linux / macOS / WSL:** run `close-remote-tab` via the Bash tool.

   If they pick `Cancel`, do nothing.
3. After running it, the session is gone — do **not** attempt any further
   response (you cannot report back).
4. If the script errors (e.g. "could not locate the current claude session
   process"), the session is still alive — surface the error verbatim.

Only ever close the current session. This skill never closes other sessions.

**Limitation:** reliably terminates only sessions started with
`open-remote-tab`. Other sessions (e.g. a plain `claude` in a terminal tab) may
restart after a kill.
