---
name: close-remote-tab
description: Use when the user asks to close, end, terminate, or quit the
  current session — e.g. "이 세션 종료", "close this session", "세션 끝내",
  "end this session". Ends the very session the user is currently in.
---

# Close the current session

The user wants to end the session they are currently in.

1. **Confirm once, with `AskUserQuestion`.** Make the consequence explicit in the
   question: terminating this session drops the connection and **no result will
   be reported back** (on mobile it shows as a disconnect). Offer two options:
   `종료` (terminate) and `취소` (cancel).
2. **Only if the user picks `종료`**, terminate the session — pick by OS:
   - **Windows:** run this plugin's `scripts/close-remote-tab.ps1` via the
     **PowerShell tool** (e.g. `& "<this-plugin>/scripts/close-remote-tab.ps1"`).
     Do **not** use the Bash tool on Windows: its Git Bash shell is not reliably
     a descendant of the current `claude.exe`, so the script's parent-process
     walk can't find the session and fails with the "could not locate" error.
     The PowerShell tool runs as a direct child of `claude.exe`, so the walk
     succeeds.
   - **Linux / macOS / WSL:** run `close-remote-tab` via the Bash tool.

   If they pick `취소`, do nothing.
3. After running it, the session is gone — do **not** attempt any further
   response (you cannot report back).
4. If the script errors (e.g. "could not locate the current claude session
   process"), the session is still alive — surface the error verbatim.

Only ever close the current session. This skill never closes other sessions.
