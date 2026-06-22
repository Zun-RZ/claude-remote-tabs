# Windows launcher for the remote-tabs plugin (invoked by bin/open-remote-tab).
# Starts a NEW, independent Claude Code remote-control session in a MINIMIZED
# window: no focus change, no VS Code needed. Visible in the taskbar so the user
# can find/close it; the window exits by itself when claude ends.
#
# Two modes:
#   - Keystroke bridge (preferred): if a Python with `winpty` (pywinpty) is found,
#     launch scripts/pty_host.py, which owns a ConPTY around `claude --remote-control`
#     and injects lines from an inbox file into its stdin. This enables built-in
#     commands like /clear (impossible for the model/hooks) to be triggered remotely.
#   - Plain fallback: no pywinpty → the original fire-and-forget minimized window
#     (no keystroke injection). Run scripts/setup-bridge.ps1 (creates a managed
#     venv, no system Python changes) to enable the bridge.
#
# NOTE: a `--remote-control` session is NOT saved locally — the conversation
# lives only on claude.ai/code (web); the local .jsonl is an empty stub.
$root = (Get-Location).Path
$proj = $root.ToLower() -replace '[:\\/]', '-'
$uid = "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-$PID"
$pidFile = Join-Path $env:TEMP "claude-remote-session-$proj-$uid.pid"
$marker = "claude-remote-$proj-$uid"

# Prefer PowerShell 7 (pwsh); fall back to Windows PowerShell 5.1 (used by fallback).
$shell = 'powershell'
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) { $shell = $pwshCmd.Source }
elseif (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") { $shell = "$env:ProgramFiles\PowerShell\7\pwsh.exe" }

# Find a Python that can `import winpty` (pywinpty). Returns @(exe, prefixArgs) or $null.
# Order: explicit override → managed venv (created by setup-bridge.ps1) → PATH pythons.
# A venv works fine — no need to install pywinpty into system Python.
function Test-Winpty([string]$exe, [string[]]$pre) {
    if (-not $exe) { return $false }
    & $exe @($pre) -c 'import winpty' 2>$null
    return ($LASTEXITCODE -eq 0)
}
function Find-PyWinpty {
    if ($env:REMOTE_TABS_PYTHON -and (Test-Path $env:REMOTE_TABS_PYTHON) -and
        (Test-Winpty $env:REMOTE_TABS_PYTHON @())) {
        return , @($env:REMOTE_TABS_PYTHON, @())
    }
    $venvPy = Join-Path $env:LOCALAPPDATA 'claude-remote-tabs\bridge-venv\Scripts\python.exe'
    if ((Test-Path $venvPy) -and (Test-Winpty $venvPy @())) { return , @($venvPy, @()) }
    foreach ($cand in @(@('python', @()), @('python3', @()), @('py', @('-3')))) {
        $g = Get-Command $cand[0] -ErrorAction SilentlyContinue
        if ($g -and (Test-Winpty $g.Source $cand[1])) { return , @($g.Source, $cand[1]) }
    }
    return $null
}

$inbox = Join-Path $env:TEMP "$marker.inbox"
$hostPy = Join-Path $PSScriptRoot 'pty_host.py'
$py = Find-PyWinpty

if ($py -and (Test-Path $hostPy)) {
    # Keystroke-bridge mode: pty_host.py spawns `claude --remote-control` in a ConPTY
    # it owns and injects inbox lines. It also sets CLAUDE_BRIDGE_INBOX in the session.
    $pyExe = $py[0]; $pyPre = $py[1]
    $argList = @() + $pyPre + @($hostPy, $inbox, '--', 'claude', '--remote-control')
    $p = Start-Process $pyExe -ArgumentList $argList `
        -WorkingDirectory $root -WindowStyle Minimized -PassThru
    [System.IO.File]::WriteAllText($pidFile, [string]$p.Id)
    Write-Output "remote session started with keystroke bridge (pid $($p.Id), minimized)"
    Write-Output "inbox: $inbox"
    Write-Output "trigger built-ins, e.g.:  Add-Content '$inbox' '/clear'"
} else {
    # Plain fallback (no pywinpty): original minimized launcher, no keystroke injection.
    $cmd = "`$host.UI.RawUI.WindowTitle = '$marker'; claude --remote-control"
    $p = Start-Process $shell -ArgumentList '-Command', $cmd `
        -WorkingDirectory $root -WindowStyle Minimized -PassThru
    [System.IO.File]::WriteAllText($pidFile, [string]$p.Id)
    Write-Output "remote session started (pid $($p.Id), minimized terminal)"
    Write-Output "note: keystroke bridge disabled (no pywinpty found). Enable /clear etc. with:"
    Write-Output "  powershell -File `"$(Join-Path $PSScriptRoot 'setup-bridge.ps1')`"   (creates a managed venv; no system Python changes)"
}
