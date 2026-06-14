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
2. **Only if the user picks `종료`**, run `close-remote-tab` via the Bash tool.
   If they pick `취소`, do nothing.
3. After running it, the session is gone — do **not** attempt any further
   response (you cannot report back).
4. If the script errors (e.g. "could not locate the current claude session
   process"), the session is still alive — surface the error verbatim.

Only ever close the current session. This skill never closes other sessions.
