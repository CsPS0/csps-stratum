<#
.SYNOPSIS
    Puts an "Apply Rider OLED theme" shortcut on the desktop.

.DESCRIPTION
    Each Rider update installs into a new versioned folder and drops the theme plugin, so the
    theme has to be rebuilt from the new install's own files. The shortcut runs
    Build-RiderTheme.ps1 -Install in a PowerShell window that stays open to show the result
    (close Rider first). Supports -WhatIf.

.EXAMPLE
    .\Add-DesktopShortcut.ps1
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Icon = (Join-Path $HOME '.config\csps-stratum\icons\dock\jetbrains-rider.ico')
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Build-RiderTheme.ps1'
$link = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Apply Rider OLED theme.lnk'
# A Store-installed pwsh lives in a versioned WindowsApps folder that changes with each update;
# its app execution alias in %LOCALAPPDATA%\Microsoft\WindowsApps stays put.
$pwsh = @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $pwsh) { $pwsh = (Get-Command pwsh).Source }

if ($PSCmdlet.ShouldProcess($link, 'Create shortcut')) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
    $s.TargetPath = $pwsh
    $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$script`" -Install"
    $s.WorkingDirectory = $PSScriptRoot
    $s.Description = 'Rebuild and install the OLED Monochrome Rider theme (close Rider first)'
    if (Test-Path -LiteralPath $Icon) { $s.IconLocation = "$Icon,0" }
    $s.Save()
    Write-Host "  [CREATE] $link"
}
