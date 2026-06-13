# Install the Claude Code remote-session open command into the current
# project (Windows). Run from the TARGET project root:
#   & <path-to-claude-remote-tabs>\setup-claude-tabs.ps1
# Idempotent: safe to run multiple times.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$claudeDir = Join-Path $root '.claude'
New-Item -ItemType Directory -Force $claudeDir | Out-Null

# Copy the per-project scripts (the installer itself stays central)
foreach ($name in 'open-remote-tab.ps1') {
    $src = Join-Path $PSScriptRoot $name
    $dst = Join-Path $claudeDir $name
    if ($src -ne $dst) { Copy-Item $src $dst -Force }
}

# Merge allow rules into project .claude/settings.json
$settingsPath = Join-Path $claudeDir 'settings.json'
$rules = @(
    "PowerShell(& $claudeDir\open-remote-tab.ps1)",
    "AskUserQuestion"
)
$obj = $null
if (Test-Path $settingsPath) {
    $obj = [System.IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
}
if ($null -eq $obj) { $obj = New-Object PSObject }
if ($obj.PSObject.Properties.Name -notcontains 'permissions') {
    $obj | Add-Member NoteProperty permissions ([pscustomobject]@{})
}
if ($obj.permissions.PSObject.Properties.Name -notcontains 'allow') {
    $obj.permissions | Add-Member NoteProperty allow @()
}
$allow = @($obj.permissions.allow)
foreach ($r in $rules) { if ($allow -notcontains $r) { $allow += $r } }
$obj.permissions.allow = $allow
# Default permission mode: auto (applies to remote sessions too, so the open
# script needs no --permission-mode flag)
if ($obj.permissions.PSObject.Properties.Name -notcontains 'defaultMode') {
    $obj.permissions | Add-Member NoteProperty defaultMode 'auto'
}
# PS5.1 ConvertTo-Json escapes & as unicode (backslash-u0026) — restore for readability
$amp = [string][char]0x5C + 'u0026'
$json = ($obj | ConvertTo-Json -Depth 16).Replace($amp, '&')
[System.IO.File]::WriteAllText($settingsPath, ($json + "`n"))
Write-Output 'settings.json: rules ok'

# Append CLAUDE.md section (only when missing)
$claudeMd = Join-Path $root 'CLAUDE.md'
$section = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'remote-tab-claude-section.md'))
$section = $section.Replace('{CLAUDE_DIR}', $claudeDir)
$section = $section.Replace('{SETUP_DIR}', $PSScriptRoot)
if ((Test-Path $claudeMd) -and ([System.IO.File]::ReadAllText($claudeMd).Contains('open-remote-tab.ps1'))) {
    Write-Output 'CLAUDE.md: section exists'
} else {
    [System.IO.File]::AppendAllText($claudeMd, "`n" + $section)
    Write-Output 'CLAUDE.md: section added'
}
Write-Output "setup done: $root"
