# Windows launcher for the remote-tabs plugin (invoked by bin/open-remote-tab).
# Starts a NEW, independent Claude Code remote-control session in a MINIMIZED
# PowerShell window: no focus change, no keystroke injection, no VS Code needed.
# The window is visible in the taskbar so the user can find/close it manually;
# the shell exits by itself when claude ends (no -NoExit).
#
# NOTE: a `--remote-control` session is NOT saved locally — the conversation
# lives only on claude.ai/code (web); the local .jsonl is an empty stub.
$root = (Get-Location).Path
$proj = $root.ToLower() -replace '[:\\/]', '-'
$uid = "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-$PID"
$pidFile = Join-Path $env:TEMP "claude-remote-session-$proj-$uid.pid"

$marker = "claude-remote-$proj-$uid"
$cmd = "`$host.UI.RawUI.WindowTitle = '$marker'; claude --remote-control"

# Prefer PowerShell 7 (pwsh); fall back to Windows PowerShell 5.1
$shell = 'powershell'
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) { $shell = $pwshCmd.Source }
elseif (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") { $shell = "$env:ProgramFiles\PowerShell\7\pwsh.exe" }

$p = Start-Process $shell -ArgumentList '-Command', $cmd `
    -WorkingDirectory $root -WindowStyle Minimized -PassThru
[System.IO.File]::WriteAllText($pidFile, [string]$p.Id)
Write-Output "remote session started (pid $($p.Id), minimized terminal)"
