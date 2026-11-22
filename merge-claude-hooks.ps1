# Merge hook registrations (<module>\.claude\hooks.json) into settings.json.
# Used by install-claude-hook.bat. Keeps other hooks and settings, backs up to settings.json.bak-<timestamp>.
# A hook already registered with the same command (path compared after normalizing slashes, case, ~ and $HOME)
# is replaced by the module's entry, so reinstalling applies changed matcher/timeout and removes duplicates.
# ASCII only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param(
    [Parameter(Mandatory)][string]$HooksJson,
    [Parameter(Mandatory)][string]$Settings,
    [Parameter(Mandatory)][string]$ClaudeHome
)
$ErrorActionPreference = 'Stop'

$claudeHomeSlash = $ClaudeHome -replace '\\', '/'
$userHome = (Split-Path -Parent $ClaudeHome) -replace '\\', '/'
$new = (Get-Content -Raw -Encoding UTF8 $HooksJson).Replace('{CLAUDE_HOME}', $claudeHomeSlash) | ConvertFrom-Json

function Normalize([string]$cmd) {
    $c = ($cmd -replace '\\', '/').Trim()
    $c = $c -replace '^~/', "$userHome/"
    $c = $c -replace '^(\$HOME|\$\{HOME\}|%USERPROFILE%)/', "$userHome/"
    return $c.ToLowerInvariant()
}
function ToJson($o) { return ($o | ConvertTo-Json -Depth 32 -Compress) }

$raw = ''
$cfg = [pscustomobject]@{}
if (Test-Path $Settings) {
    $raw = Get-Content -Raw -Encoding UTF8 $Settings
    $cfg = $raw | ConvertFrom-Json
}
if (-not $cfg.PSObject.Properties['hooks']) {
    $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

$changed = $false
foreach ($evt in $new.PSObject.Properties) {
    $name = $evt.Name
    if (-not $cfg.hooks.PSObject.Properties[$name]) {
        $cfg.hooks | Add-Member -NotePropertyName $name -NotePropertyValue @()
    }
    $list = @($cfg.hooks.$name)
    $before = ToJson $list
    foreach ($entry in $evt.Value) {
        $cmds = @($entry.hooks | ForEach-Object { Normalize $_.command })
        $out = @()
        $placed = $false
        foreach ($old in $list) {
            $keep = @($old.hooks | Where-Object { $cmds -notcontains (Normalize $_.command) })
            if ($keep.Count -eq @($old.hooks).Count) { $out += $old; continue }
            # This entry held our hook: put the module's entry here once, keep any other hooks it had.
            if (-not $placed) { $out += $entry; $placed = $true }
            if ($keep.Count -gt 0) { $old.hooks = $keep; $out += $old }
        }
        if (-not $placed) { $out += $entry }
        $list = $out
    }
    if ((ToJson $list) -ne $before) {
        $cfg.hooks.$name = $list
        $changed = $true
        Write-Host "  [settings] $name : registered/updated $(@($evt.Value | ForEach-Object { $_.hooks } | ForEach-Object { $_.command }) -join ', ')"
    } else {
        Write-Host "  [settings] $name : already up to date, skipped"
    }
}

if (-not $changed) { exit 0 }
if (Test-Path $Settings) {
    $bak = "$Settings.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $Settings $bak -Force
    Write-Host "  [settings] backup: $bak"
}
$json = $cfg | ConvertTo-Json -Depth 32
if (-not $raw.Contains("`r`n")) { $json = $json -replace "`r`n", "`n" }
[IO.File]::WriteAllText($Settings, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
