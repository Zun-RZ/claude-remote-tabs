# Start a Remote Control session for this project in a minimized terminal.
# Fully background: no focus change, no keystroke injection, no VS Code needed.
# Each call starts a NEW, independent session (unique marker + PID file) so
# multiple remote sessions can run side by side for the same project.
#
# NOTE (2026-06-14): we pass `/remote-control` as the initial prompt instead of the
# `--remote-control` start flag. The start flag does NOT persist the session locally
# (can't --resume/--teleport; the local file is an empty stub and the conversation
# lives only on claude.ai/code). Passing the slash command starts a normal local
# session and toggles remote control inside it, so the session IS saved locally and
# reopenable. (Suspected Claude Code bug: the docs say both entry points behave the
# same; in practice the start flag doesn't persist.)
$root = (Get-Location).Path
$proj = $root.ToLower() -replace '[:\\/]', '-'
$uid = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$pidFile = Join-Path $env:TEMP "claude-remote-session-$proj-$uid.pid"

$marker = "claude-remote-$proj-$uid"
$cmd = "`$host.UI.RawUI.WindowTitle = '$marker'; claude '/remote-control'"

# Prefer PowerShell 7 (pwsh); fall back to Windows PowerShell 5.1
$shell = 'powershell'
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) { $shell = $pwshCmd.Source }
elseif (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") { $shell = "$env:ProgramFiles\PowerShell\7\pwsh.exe" }

# Minimized host window: visible in the taskbar so the user can find/close it
# manually; the shell exits by itself when claude ends (no -NoExit).
$p = Start-Process $shell -ArgumentList '-Command', $cmd `
    -WorkingDirectory $root -WindowStyle Minimized -PassThru
[System.IO.File]::WriteAllText($pidFile, [string]$p.Id)
Write-Output "remote session started (pid $($p.Id), minimized terminal)"
