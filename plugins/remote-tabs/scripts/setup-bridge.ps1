# One-time setup for the remote-tabs keystroke bridge (Windows).
# Creates a MANAGED venv with pywinpty so open-remote-tab can inject keystrokes
# (/clear etc.) into a remote session — WITHOUT touching system Python.
# Idempotent: re-running just ensures pywinpty is present. Delete the venv dir to undo.
#
# The venv lives at %LOCALAPPDATA%\claude-remote-tabs\bridge-venv; open-remote-tab.ps1
# auto-discovers it. (You can also point REMOTE_TABS_PYTHON at any python with pywinpty.)
$ErrorActionPreference = 'Stop'
$venvDir = Join-Path $env:LOCALAPPDATA 'claude-remote-tabs\bridge-venv'
$venvPy = Join-Path $venvDir 'Scripts\python.exe'

# A base Python is required to build the venv (pywinpty is a Python lib).
function Find-BasePython {
    foreach ($cand in @(@('python', @()), @('python3', @()), @('py', @('-3')))) {
        $g = Get-Command $cand[0] -ErrorAction SilentlyContinue
        if (-not $g) { continue }
        & $g.Source @($cand[1]) -c 'import sys' 2>$null
        if ($LASTEXITCODE -eq 0) { return , @($g.Source, $cand[1]) }
    }
    return $null
}

if (-not (Test-Path $venvPy)) {
    $base = Find-BasePython
    if (-not $base) {
        [Console]::Error.WriteLine('setup-bridge: no Python found. Install Python 3 (python.org or winget install Python.Python.3.12), then re-run.')
        exit 1
    }
    Write-Output "creating venv at $venvDir (base: $($base[0]) $($base[1]))..."
    & $base[0] @($base[1]) -m venv $venvDir
}

Write-Output "installing pywinpty into the managed venv..."
& $venvPy -m pip install --quiet --upgrade pip pywinpty

& $venvPy -c 'import winpty; print("pywinpty OK -> bridge enabled")'
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine('setup-bridge: pywinpty install/import failed.')
    exit 1
}
Write-Output "done. open-remote-tab will now start sessions in keystroke-bridge mode."
