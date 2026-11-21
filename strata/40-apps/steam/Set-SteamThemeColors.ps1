<#
.SYNOPSIS
    Writes the OLED Monochrome colours for the SpaceTheme Steam theme into Millennium's config.

.DESCRIPTION
    Copies theme-colors.json into themes.themeColors of Millennium's config.json (the same
    place Millennium's own colour pickers save to). Only the themes listed in
    theme-colors.json are touched. It also installs quick.css as Millennium's Quick CSS,
    for the few colours the theme and Steam hard-code. Timestamped .bak copies of
    config.json and quick.css are written first.
    Steam must be closed, because Millennium writes its config back when Steam exits.
    Supports -WhatIf.

.EXAMPLE
    .\Set-SteamThemeColors.ps1 -WhatIf
    .\Set-SteamThemeColors.ps1
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SteamPath = ((Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath -replace '/', '\')
)

$ErrorActionPreference = 'Stop'
if (-not $SteamPath) { throw 'Steam install not found; pass -SteamPath' }
$config = Join-Path $SteamPath 'millennium\config\config.json'
if (-not (Test-Path $config)) { throw "Millennium config not found: $config" }

$colors = Get-Content -Raw (Join-Path $PSScriptRoot 'theme-colors.json') | ConvertFrom-Json -AsHashtable
$json = Get-Content -Raw $config | ConvertFrom-Json -AsHashtable
if (-not $json.themes) { throw 'config.json has no "themes" section' }
if (-not $json.themes.themeColors) { $json.themes.themeColors = [ordered]@{} }

foreach ($theme in $colors.Keys) {
    $old = $json.themes.themeColors[$theme]
    foreach ($k in $colors[$theme].Keys) {
        $from = if ($old) { $old[$k] } else { $null }
        if ($from -ne $colors[$theme][$k]) { Write-Host ("  {0} {1}: {2} -> {3}" -f $theme, $k, ($from ?? '(theme default)'), $colors[$theme][$k]) }
    }
    $json.themes.themeColors[$theme] = $colors[$theme]
}

if ($PSCmdlet.ShouldProcess($config, 'Write theme colours')) {
    if (Get-Process steam -ErrorAction SilentlyContinue) { throw 'Close Steam first (Steam > Exit); Millennium rewrites config.json on exit' }
    $bak = "$config.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
    Copy-Item -LiteralPath $config -Destination $bak
    Write-Host "  [BACKUP] $bak"
    Set-Content -LiteralPath $config -Value ($json | ConvertTo-Json -Depth 20) -Encoding utf8NoBOM
    Write-Host "  [WRITE] $config"
}

# Quick CSS: greys for the colours the theme and Steam hard-code
$quick = Join-Path (Split-Path $config) 'quick.css'
$src = Join-Path $PSScriptRoot 'quick.css'
if ((Test-Path $quick) -and (Get-FileHash $quick).Hash -eq (Get-FileHash $src).Hash) {
    Write-Host "  [SAME] $quick"
} elseif ($PSCmdlet.ShouldProcess($quick, 'Write Quick CSS')) {
    if (Test-Path $quick) {
        $bak = "$quick.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
        Copy-Item -LiteralPath $quick -Destination $bak
        Write-Host "  [BACKUP] $bak"
    }
    Copy-Item -LiteralPath $src -Destination $quick -Force
    Write-Host "  [WRITE] $quick"
}
