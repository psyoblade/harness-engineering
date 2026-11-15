# Merge hook registrations (<module>\.claude\hooks.json) into settings.json.
# Used by install-claude-hook.bat. Keeps existing hooks, skips duplicates, backs up to settings.json.bak.
# ASCII only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param(
    [Parameter(Mandatory)][string]$HooksJson,
    [Parameter(Mandatory)][string]$Settings,
    [Parameter(Mandatory)][string]$ClaudeHome
)
$ErrorActionPreference = 'Stop'

$claudeHomeSlash = $ClaudeHome -replace '\\', '/'
$new = (Get-Content -Raw -Encoding UTF8 $HooksJson).Replace('{CLAUDE_HOME}', $claudeHomeSlash) | ConvertFrom-Json

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
    $existing = @($cfg.hooks.$name | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
    foreach ($entry in $evt.Value) {
        $cmds = @($entry.hooks | ForEach-Object { $_.command })
        if ($cmds | Where-Object { $existing -contains $_ }) {
            Write-Host "  [settings] $name : already registered, skipped"
        } else {
            $cfg.hooks.$name = @($cfg.hooks.$name) + $entry
            $changed = $true
            Write-Host "  [settings] $name : registered $($cmds -join ', ')"
        }
    }
}

if (-not $changed) { exit 0 }
if (Test-Path $Settings) { Copy-Item $Settings "$Settings.bak" -Force }
$json = $cfg | ConvertTo-Json -Depth 32
if (-not $raw.Contains("`r`n")) { $json = $json -replace "`r`n", "`n" }
[IO.File]::WriteAllText($Settings, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
