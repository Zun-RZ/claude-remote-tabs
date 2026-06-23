# Windows launcher for the remote-tabs plugin (invoked by bin/open-remote-tab).
# Starts a NEW, independent Claude Code remote-control session in the background:
# no focus change, no VS Code needed. The session exits by itself when claude ends.
#
# Two modes:
#   - Keystroke bridge (preferred): if a Python with `winpty` (pywinpty) is found,
#     launch scripts/pty_host.py, which owns a ConPTY around `claude --remote-control`
#     and injects lines from an inbox file into its stdin. This enables built-in
#     commands like /clear (impossible for the model/hooks) to be triggered remotely.
#     NO console window ever appears, on any default terminal: pty_host forces the
#     headless ConPTY backend (CreatePseudoConsole — see pty_host.py), and it is
#     itself launched windowless (python.exe + CREATE_NO_WINDOW). close_fds also
#     detaches it cleanly — the child holds none of our handles, so the launcher
#     returns immediately instead of blocking until the session ends (see the
#     bridge block below for the full why).
#   - Plain fallback: no pywinpty → a fire-and-forget minimized window (no keystroke
#     injection; needs a console for claude's TUI). Run scripts/setup-bridge.ps1
#     (creates a managed venv, no system Python changes) to enable the bridge.
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
    if ($env:REMOTE_TABS_WINDOW) {
        # Window mode (REMOTE_TABS_WINDOW set): run pty_host in a MINIMIZED, visible
        # console so its stdin is a real console — that re-enables pty_host's local
        # input forwarding (type into the taskbar window, Korean/IME included). The
        # self-gating lives in pty_host (enable_console_raw); here we just give it a
        # console. -WindowStyle Minimized keeps it off-screen-but-reachable; Start-Process
        # returns at once, so the launcher never blocks.
        $rest = $pyPre + @($hostPy, $inbox, '--', 'claude', '--remote-control')
        $argStr = ($rest | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
        $p = Start-Process $pyExe -ArgumentList $argStr `
            -WorkingDirectory $root -WindowStyle Minimized -PassThru
        [System.IO.File]::WriteAllText($pidFile, [string]$p.Id)
        Write-Output "remote session started with keystroke bridge (pid $($p.Id), minimized window)"
        Write-Output "inbox: $inbox"
        Write-Output "trigger built-ins, e.g.:  Add-Content '$inbox' '/clear'"
    } else {
        # Default (no window): launch pty_host so NO console window ever flashes AND the
        # launcher never blocks. pty_host's local-input forwarding stays inert here — its
        # stdin is DEVNULL, so enable_console_raw() returns None and it no-ops.
        # No window appears from two independent pieces:
        #   - The bridge's own ConPTY is headless: pty_host forces backend=ConPTY
        #     (CreatePseudoConsole), so winpty never spawns a console window for the PTY.
        #     (A black window briefly flashed on first open when the backend fell back to
        #     legacy WinPTY, whose winpty-agent.exe makes its own console — see pty_host.py.)
        #   - pty_host itself is windowless: CREATE_NO_WINDOW (0x08000000) gives python.exe
        #     a console WITHOUT a window, so the host process shows nothing either.
        #   - close_fds: the child inherits none of our standard handles, so neither pty_host
        #     nor its descendant claude holds the caller's stdout pipe open — the launcher
        #     returns at once instead of blocking until the session ends.
        # ps1 itself runs under a console-less powershell (the bin/ wrapper starts it with
        # CREATE_NO_WINDOW), so calling python.exe directly would pop a new console window.
        # Route through a one-shot Python helper, itself launched .NET CreateNoWindow, which
        # Popens pty_host with the flags above and prints its pid back.
        $helper = 'import subprocess,sys; p=subprocess.Popen([sys.executable]+sys.argv[1:],creationflags=0x08000000,close_fds=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); print(p.pid)'
        $rest = $pyPre + @('-c', $helper, $hostPy, $inbox, '--', 'claude', '--remote-control')
        $argStr = ($rest | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = $pyExe
        $psi.Arguments = $argStr
        $psi.WorkingDirectory = $root
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow  = $true
        $psi.RedirectStandardOutput = $true
        $hp = [System.Diagnostics.Process]::Start($psi)
        $childPid = $hp.StandardOutput.ReadLine()
        $hp.WaitForExit()
        [System.IO.File]::WriteAllText($pidFile, [string]$childPid)
        Write-Output "remote session started with keystroke bridge (pid $childPid, no window)"
        Write-Output "inbox: $inbox"
        Write-Output "trigger built-ins, e.g.:  Add-Content '$inbox' '/clear'"
    }
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
