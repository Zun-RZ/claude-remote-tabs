# Windows side of `close-remote-tab` (invoked by bin/close-remote-tab).
# Ends the CURRENT Claude Code session by walking up the process tree from this
# script to the first `claude.exe` (or `node.exe`) ancestor and terminating it.
#
# We kill ONLY that process (no tree kill): the in-flight killer is itself a
# descendant of claude, and when claude exits the minimized launcher window
# closes on its own (its `-Command "claude --remote-control"` completes). So a
# tree kill would both risk a race and is unnecessary.
#
# -DryRun: print the target without killing (for safe verification).
param([switch]$DryRun)

$p = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
$target = $null
while ($p) {
    if ($p.Name -ieq 'claude.exe' -or $p.Name -ieq 'node.exe') { $target = $p; break }
    if (-not $p.ParentProcessId -or $p.ParentProcessId -eq 0) { break }
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction SilentlyContinue
}

if (-not $target) {
    [Console]::Error.WriteLine('close-remote-tab: could not locate the current claude session process')
    exit 1
}

if ($DryRun) {
    Write-Output "would terminate $($target.Name) (pid $($target.ProcessId))"
    exit 0
}

Stop-Process -Id $target.ProcessId -Force
Write-Output "session terminated (pid $($target.ProcessId))"
